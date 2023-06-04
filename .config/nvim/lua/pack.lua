local M = {}
local Trace = require 'trace'
local uv = vim.loop

local path2plugin = {}
local lua2path = {}

local source_blacklist

local function scandir_empty()
	-- Just return nil.
end

local function scandir(path)
	local handle = uv.fs_scandir(path)
	if handle then
		return uv.fs_scandir_next, handle
	end
	return scandir_empty
end

local function echo_error(...)
	vim.api.nvim_echo({
		{'pack: ', 'ErrorMsg'},
		{string.format(...), 'ErrorMsg'}
	}, true, {})
end

local function vim_cmd_source(file)
	local ok, err
	if string.match(file, '%.lua$') then
		ok, err = pcall(dofile, file)
	else
		ok, err = pcall(vim.cmd.source, file)
	end
	if not ok then
		echo_error('Error detected while processing %s:\n%s', file, err)
	end
end

-- &packpath/pack/*/opt/{name}[/after]
function get_packpath_dirs()
	local span = Trace.trace('find pack plugins')

	local before, after = {}, {}

	for _, root in ipairs(vim.opt.packpath:get()) do
		local pack = root .. '/pack'
		for star, kind in scandir(pack) do
			if kind ~= 'file' then
				local opt = string.format('%s/%s/opt', pack, star)
				for name, kind in scandir(opt) do
					if kind ~= 'file' then
						local path = string.format('%s/%s', opt, name)
						before[name] = before[name] or {}
						table.insert(before[name], path)

						after[name] = after[name] or {}
						local after_path = path .. '/after'
						if uv.fs_access(after_path, 'x') then
							table.insert(after[name], after_path)
						end
					end
				end
			end
		end
	end

	Trace.trace(span)

	return before, after
end

local function is_source_allowed(file)
	for _, pat in ipairs(source_blacklist) do
		if string.find(file, pat) then
			return false
		end
	end
	return true
end

local function source_file(file, plugin)
	if not is_source_allowed(file) then
		return
	end

	local span = Trace.trace(string.format(
		'source %s (from %s)',
		file,
		plugin and plugin.id or '<no plugin>'
	))
	vim_cmd_source(file)
	Trace.trace(span)
end

local function source_dir(dir, plugin)
	for name, kind in scandir(dir) do
		local path = string.format('%s/%s', dir, name)
		if kind == 'directory' then
			source_dir(path, plugin)
		else
			source_file(path, plugin)
		end
	end
end

local function package_loader(path)
	-- :h require()
	local head, tail = string.match(path, '^([^.]*)(.*)')
	local path = lua2path[head]
	if path then
		local prefix = path .. string.gsub(tail, '%.', '/')

		local ok, code = pcall(loadfile, prefix .. '.lua')
		if ok then
			return code
		end

		local ok, code = pcall(loadfile, prefix .. '/init.lua')
		if ok then
			return code
		end
	end
end

local function initialize_plugins()
	assert(vim.v.vim_did_enter == 0, 'Vim already initialized')

	local span = Trace.trace('get &runtimepath')

	-- PERF: Much faster than vim.opt.runtimepath:get().
	local rtp = vim.api.nvim_list_runtime_paths()

	local span = Trace.trace(span, 'initialize lua package cache')

	for _, path in ipairs(rtp) do
		local dir = path .. '/lua'
		for name in scandir(dir) do
			local path = string.format('%s/%s', dir, name)
			lua2path[name] = path
		end
	end

	table.insert(package.loaders, 2, package_loader)

	local span = Trace.trace(span, 'initialize plugins')

	-- Plugin loading is taken over.
	vim.o.loadplugins = false

	-- PERF: Same but uses much less stat calls:
	-- vim.cmd "runtime! plugin/**/*.vim plugin/**/*.lua"
	for _, path in ipairs(rtp) do
		source_dir(path .. '/plugin', path2plugin[path])
	end

	Trace.trace(span)
end

function M.plugin_missing(plugin)
	echo_error("Plugin '%s' not found", plugin.id)
end

function M.plugin_before(plugin)
	if plugin.before then
		return plugin:before()
	end
end

function M.plugin_after(plugin)
	if plugin.after then
		return plugin:after()
	end

	if plugin.opts == nil then
		return
	end

	local name = plugin.id
		:gsub('^n?vim[.-]', '')
		:gsub('[.-]n?vim$', '')
	local ok, package = pcall(require, name)
	if
		ok and
		type(package) == 'table' and
		type(package.setup) == 'function'
	then
		return package.setup(plugin.opts)
	else
		echo_error(
			"Plugin '%s' specifies 'opts' but cannot find setup function. Use 'after' to call it.",
			plugin.id
		)
	end
end

function M.setup(spec, opts)
	local setup_span = Trace.trace('setup')

	collectgarbage('stop')

	opts = vim.tbl_extend('force', {
		source_blacklist = {},
	}, opts or {})

	source_blacklist = opts.source_blacklist

	local pp_before, pp_after = get_packpath_dirs()
	local rtp_prepend, rtp_append = {}, {}

	-- Same as :packadd! but does fewer stat calls.
	local function packadd(plugin)
		local found = false
		for _, x in ipairs(pp_before[plugin.id] or {}) do
			table.insert(rtp_prepend, x)
			path2plugin[x] = plugin
			found = true
		end
		for _, x in ipairs(pp_after[plugin.id] or {}) do
			table.insert(rtp_append, x)
			path2plugin[x] = plugin
			found = true
		end
		return found
	end

	local plugins = {}
	for _, plugin in ipairs(spec) do
		if type(plugin) == 'string' then
			plugin = {
				plugin,
			}
		end
		plugin.id = plugin[1]

		if
			plugin.enabled ~= false and
			(
				packadd(plugin) or
				M.plugin_missing(plugin)
			)
		then
			plugins[plugin.id] = plugin
			M.plugin_before(plugin)
		end
	end

	local span = Trace.trace('set &runtimepath')
	-- PERF: Modify 'runtimepath' in a batch call since it is much faster.
	local rtp = vim.opt.runtimepath
	rtp:prepend(rtp_prepend)
	rtp:append(rtp_append)
	Trace.trace(span)

	initialize_plugins()

	local span = Trace.trace('after plugins')

	for _, plugin in pairs(plugins) do
		local span = Trace.trace(plugin.id)
		M.plugin_after(plugin)
		Trace.trace(span)
	end

	Trace.trace(span)

	collectgarbage('restart')

	Trace.trace(setup_span)
end

return M
