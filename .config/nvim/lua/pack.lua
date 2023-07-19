local M = {}
local Trace = require('trace')
local uv = vim.loop
local api = vim.api
local pairs, ipairs = pairs, ipairs
local string_format, string_match, string_find, string_gsub =
	string.format, string.match, string.find, string.gsub
local table_insert = table.insert

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
	api.nvim_echo({
		{ 'pack: ', 'ErrorMsg' },
		{ string_format(...), 'ErrorMsg' },
	}, true, {})
end

local function vim_cmd_source(file)
	local ok, err
	if string_match(file, '%.lua$') then
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
				local opt = string_format('%s/%s/opt', pack, star)
				for name, kind in scandir(opt) do
					if kind ~= 'file' then
						local path = string_format('%s/%s', opt, name)
						before[name] = before[name] or {}
						table_insert(before[name], path)

						after[name] = after[name] or {}
						local after_path = path .. '/after'
						if uv.fs_access(after_path, 'x') then
							table_insert(after[name], after_path)
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
		if string_find(file, pat) then
			return false
		end
	end
	return true
end

local function source_file(file, plugin)
	if not is_source_allowed(file) then
		return
	end

	local span = Trace.trace(
		string_format(
			'source %s (from %s)',
			file,
			plugin and plugin.id or '<no plugin>'
		)
	)
	vim_cmd_source(file)
	Trace.trace(span)
end

local function source_dir(dir, plugin)
	for name, kind in scandir(dir) do
		local path = string_format('%s/%s', dir, name)
		if kind == 'directory' then
			source_dir(path, plugin)
		else
			source_file(path, plugin)
		end
	end
end

local function package_loader(path)
	-- :h require()
	local head, tail = string_match(path, '^([^.]*)(.*)')
	local path = lua2path[head]
	if path then
		local prefix = path .. string_gsub(tail, '%.', '/')

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
	local trace = Trace.trace
	assert(vim.v.vim_did_enter == 0, 'Vim already initialized')

	local span = trace('get &runtimepath')

	-- PERF: Much faster than vim.opt.runtimepath:get().
	local rtp = api.nvim_list_runtime_paths()

	local span = trace(span, 'initialize lua package cache')

	for _, path in ipairs(rtp) do
		local dir = path .. '/lua'
		for name in scandir(dir) do
			local path = string_format('%s/%s', dir, name)
			lua2path[name] = path
		end
	end

	table_insert(package.loaders, 2, package_loader)

	local span = trace(span, 'initialize plugins')

	-- Plugin loading is taken over.
	vim.o.loadplugins = false

	-- PERF: Same but uses much less stat calls:
	-- vim.cmd "runtime! plugin/**/*.vim plugin/**/*.lua"
	for _, path in ipairs(rtp) do
		source_dir(path .. '/plugin', path2plugin[path])
	end

	trace(span)
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
end

function M.setup(spec, opts)
	local trace = Trace.trace
	local setup_span = trace('setup')

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
			table_insert(rtp_prepend, x)
			path2plugin[x] = plugin
			found = true
		end
		for _, x in ipairs(pp_after[plugin.id] or {}) do
			table_insert(rtp_append, x)
			path2plugin[x] = plugin
			found = true
		end
		return found
	end

	local plugins = {}
	for _, plugin in ipairs(spec) do
		plugin.id = plugin[1]

		if
			plugin.enabled ~= false and (packadd(plugin) or M.plugin_missing(plugin))
		then
			plugins[plugin.id] = plugin
			M.plugin_before(plugin)
		end
	end

	local span = trace('set &runtimepath')
	-- PERF: Modify 'runtimepath' in a batch call since it is much faster.
	local rtp = vim.opt.runtimepath
	rtp:prepend(rtp_prepend)
	rtp:append(rtp_append)
	trace(span)

	initialize_plugins()

	local span = trace('after plugins')

	for _, plugin in pairs(plugins) do
		local span = trace(plugin.id)
		M.plugin_after(plugin)
		trace(span)
	end

	trace(span)

	collectgarbage('restart')

	trace(setup_span)
end

return M
