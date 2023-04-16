local M = {}
local Trace = require 'trace'
local uv = vim.loop

local path2plugin = {}
local autoload_path = vim.fn.stdpath('cache') .. '/autoload.lua'
local autoload
local autoload_aux = {}
local generate_autoload
local seen_commands = {}
local seen_keymap = {}
local seen_autocmds = {}
local seen_abbrevs = {}

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
	vim.api.nvim_echo({{string.format(...), 'ErrorMsg'}}, true, {})
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

local function autoload_uninstall(index)
	local data = autoload[index]
	local data_aux = autoload_aux[index]

	if not data_aux.installed then
		return false
	end
	data_aux.installed = false

	vim.api.nvim_del_augroup_by_id(data_aux.group)

	for _, def in ipairs(data.commands) do
		pcall(vim.api.nvim_del_user_command, def.name)
	end

	for _, def in ipairs(data.keymap) do
		vim.api.nvim_del_keymap(def.mode, def.lhs)
	end

	for _, def in ipairs(data.abbrevs) do
		local abbrev = string.format('%sunabbrev', def.mode)
		vim.cmd[abbrev](def.lhs)
	end

	return true
end

local function autoload_kill(index)
	uv.fs_unlink(autoload_path, function() end)
	generate_autoload = false
end

local function autoload_load(index)
	if vim.in_fast_event() then
		vim.schedule(function()
			autoload_load(index)
		end)
		return
	end

	if autoload_uninstall(index) then
		vim_cmd_source(autoload[index].source)
	end
end

function _G._pack_hotswap_abbrev(index, wanted_mode, wanted_lhs)
	local cmdtype = vim.fn.getcmdtype()
	local cmdline = vim.fn.getcmdline()

	autoload_load(index)

	-- FIXME: It is a piece of shit but works for my use-cases.
	-- WTF: :abbrev does not show output in mode "c".
	if vim.fn.mode() == 'c' then
		if vim.v.char ~= '\r' then
			vim.api.nvim_input('<BS>' .. vim.v.char)
			return cmdline
		end
		vim.api.nvim_input(cmdtype .. cmdline .. vim.v.char)
		vim.fn.setcmdline('')
		return ''
	else
		for lhs, rhs in string.gmatch(
			vim.api.nvim_exec(wanted_mode .. 'abbrev', true),
			'. +([^ ]+) +[*&@]? +([^\n]+)\n?'
		) do
			if lhs == wanted_lhs then
				-- We do not know if mapping is <expr> or not.
				local ok, value = pcall(vim.api.nvim_eval, rhs)
				if ok then
					return value
				else
					return rhs
				end
			end
		end
		assert(false)
	end
end

local function autoload_install(index)
	local data = autoload[index]

	local group = vim.api.nvim_create_augroup('pack/' .. data.source, {})

	local hotswap_preview = function()
		autoload_load(index)
	end

	for _, def in ipairs(data.commands) do
		local hotswap = function(opts)
			autoload_load(index)
			-- TODO: Add support for ranges and registers.
			vim.cmd(string.format('%s%s %s', def.name, opts.bang and '!' or '', opts.args))
		end

		vim.api.nvim_create_user_command(def.name, hotswap, {
			preview = def.preview and hotswap_preview,
			desc = def.desc,
			nargs = '*',
			bang = true,
			range = 2,
		})
	end

	for _, def in ipairs(data.keymap) do
		local hotswap = function()
			autoload_load(index)
			vim.api.nvim_feedkeys(
				vim.api.nvim_replace_termcodes(def.lhs, true, false, true),
				'ti',
				false
			)
		end

		vim.api.nvim_set_keymap(def.mode, def.lhs, '', {
			expr = true,
			desc = def.desc,
			nowait = def.nowait,
			callback = hotswap,
		})
	end

	for _, def in ipairs(data.autocmds) do
		local hotswap = function()
			autoload_load(index)
			vim.api.nvim_exec_autocmds(def.event, {
				group = def.group_name,
			})
		end

		vim.api.nvim_create_autocmd(def.event, {
			group = group,
			pattern = def.pattern,
			once = true,
			callback = hotswap,
		})
	end

	for _, def in ipairs(data.abbrevs) do
		local abbrev = string.format(
			'%s%sabbrev',
			def.mode,
			def.noremap and 'nore' or ''
		)
		local rhs = string.format(
			'v:lua._pack_hotswap_abbrev(%d, "%s", "%s")',
			index,
			def.mode,
			def.lhs
		)
		vim.cmd[abbrev]('<expr>', def.lhs, rhs)
	end

	autoload_aux[index] = {
		installed = true,
		group = group,
	}
end

local function autoload_analyze(file)
	local span = Trace.trace('analyze ' .. (file or '<vim>'))

	local new_commands = {}
	local new_keymap = {}
	local new_autocmds = {}
	local new_abbrevs = {}

	for _, def in pairs(vim.api.nvim_get_commands({})) do
		local key = def.name
		if not seen_commands[key] and file then
			table.insert(new_commands, {
				name = def.name,
				desc = def.desc or nil,
				preview = def.preview or nil,
			})
		end
		seen_commands[key] = true
	end

	local NVO = {'n', 'v', 'o'}
	for _, mode in ipairs({'c', 'i', 'l', 'n', 'o', 't', 'v'}) do
		for _, def in ipairs(vim.api.nvim_get_keymap(mode)) do
			local key = string.format('%s,%s', def.mode, def.lhs)
			if not seen_keymap[key] and file then
				for _, m in ipairs(def.mode == ' ' and NVO or {def.mode}) do
					table.insert(new_keymap, {
						mode = m,
						lhs = def.lhs,
						desc = def.desc,
						nowait = def.nowait,
					})
				end
			end
			seen_keymap[key] = true
		end
	end

	for _, def in ipairs(vim.api.nvim_get_autocmds({})) do
		-- FIXME: Key may not unique.
		local key = string.format('%s,%s,%s', def.group_name or '', def.event, def.pattern)
		if not seen_autocmds[key] and file then
			table.insert(new_autocmds, {
				group_name = def.group_name,
				event = def.event,
				pattern = def.pattern,
			})
		end
		seen_autocmds[key] = true
	end

	for mode, lhs, noremap in string.gmatch(
		vim.api.nvim_exec('abbrev', true),
		'(.) +([^ ]+) +(%*?)[^\n]*\n?'
	) do
		local key = string.format('%s,%s,%s', mode, lhs, noremap)
		if not seen_abbrevs[key] and file then
			table.insert(new_abbrevs, {
				mode = mode,
				lhs = lhs,
				noremap = noremap == '*' or nil,
			})
		end
		seen_abbrevs[key] = true
	end

	Trace.trace(span)

	if not file then
		return
	end

	table.insert(autoload, {
		source = file,
		commands = new_commands,
		keymap = new_keymap,
		autocmds = new_autocmds,
		abbrevs = new_abbrevs,
	})
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

	if not generate_autoload then
		local data = autoload[file]
		if data then
			if #data.commands + #data.keymap + #data.autocmds + #data.abbrevs > 0 then
				return
			end
		else
			autoload_kill()
		end
	end

	local span = Trace.trace(string.format(
		'sourcing %s (from %s)',
		file,
		plugin and plugin.name or '<no plugin>'
	))
	vim_cmd_source(file)
	Trace.trace(span)

	if generate_autoload then
		if not (plugin and plugin.on == true) then
			autoload_analyze(file)
		else
			-- Create blanket entry.
			table.insert(autoload, {
				source = file,
				commands = {},
				keymap = {},
				autocmds = {},
				abbrevs = {},
			})
		end
	end
end

local function source_dir(path, plugin)
	for name, kind in scandir(path) do
		local fullname = string.format('%s/%s', path, name)
		if kind == 'directory' then
			source_dir(fullname, plugin)
		else
			source_file(fullname, plugin)
		end
	end
end

local function initialize_plugins()
	assert(vim.v.vim_did_enter == 0, 'Vim already initialized')

	local span = Trace.trace('get &runtimepath')

	-- PERF: Much faster than vim.opt.runtimepath:get().
	local rtp = vim.api.nvim_list_runtime_paths()

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

function M.plugin_not_found(plugin)
	echo_error("Plugin '%s' not found", plugin.name)
end

local function extend_strict(left, right)
	for k, v in pairs(right or {}) do
		local t = type(left[k])
		if t == 'nil' then
			error(string.format('invalid key: %s', k))
		elseif t ~= type(v) then
			error(string.format("bad value to '%s' (%s expected, got %s)", k, t, type(v)))
		end
		left[k] = v
	end
	return left
end

function M.setup(spec, opts)
	local setup_span = Trace.trace('setup')

	collectgarbage('stop')

	opts = extend_strict({
		source_blacklist = {},
		autoload = true,
	}, opts)

	source_blacklist = opts.source_blacklist

	-- Restore autoload data.
	if opts.autoload then
		local span = Trace.trace('init autoload')
		local ok, code = pcall(loadfile, autoload_path)
		if ok then
			local span = Trace.trace('autoload data')
			autoload = code()
			Trace.trace(span)
			generate_autoload = false

			for i, data in ipairs(autoload) do
				autoload[data.source] = data
				autoload_install(i)
			end
		else
			autoload = {}
			generate_autoload = true
		end
		Trace.trace(span)
	else
		autoload = {}
		generate_autoload = false
	end

	if generate_autoload then
		autoload_analyze()
	end

	local pp_before, pp_after = get_packpath_dirs()
	local rtp_prepend, rtp_append = {}, {}

	-- Same as :packadd! but does fewer stat calls.
	local function packadd(plugin)
		local found = false
		for _, x in ipairs(pp_before[plugin.name] or {}) do
			table.insert(rtp_prepend, x)
			path2plugin[x] = plugin
			found = true
		end
		for _, x in ipairs(pp_after[plugin.name] or {}) do
			table.insert(rtp_append, x)
			path2plugin[x] = plugin
			found = true
		end
		return found
	end

	for k, v in pairs(spec) do
		-- Plugin specification can be given in multiple formats:
		-- - [0] = "<name>"
		-- - [0] = { <spec> }
		-- - <name> = <enabled>
		-- - <name> = { <spec> }
		if type(k) == 'number' and type(v) == 'string' then
			v = { name = v }
		elseif type(k) == 'string' and type(v) == 'boolean' then
			v = {
				name = k,
				enabled = v,
			}
		elseif type(k) == 'string' and type(v) == 'table' then
			assert(not v.name)
			assert(not v[1])
			v.name = k
		else
			assert(type(k) == 'number' and type(v) == 'table')
			assert(v[1])
			assert(not v.name)
			v.name = v[1]
		end

		local plugin = v

		if plugin.enabled ~= false then
			if not packadd(plugin) then
				M.plugin_not_found(plugin)
			end
		end
	end

	local span = Trace.trace('set &runtimepath')
	-- PERF: Modify 'runtimepath' in a batch call since it is much faster.
	local rtp = vim.opt.runtimepath
	rtp:prepend(rtp_prepend)
	rtp:append(rtp_append)
	Trace.trace(span)

	initialize_plugins()

	local span = Trace.trace('post init autoload')

	local k = #autoload
	for index, data in ipairs(autoload) do
		uv.fs_stat(data.source, function(err, stat)
			-- File gone.
			if err then
				autoload_kill()
			end

			k = k - 1

			if stat then
				local hash = string.format(
					'S=%s,M=%s_%s',
					stat.size,
					stat.mtime.sec,
					stat.mtime.nsec
				)
				if data.hash and data.hash ~= hash then
					autoload_load(index)
					autoload_kill()
				end
				data.hash = hash
			end

			if k > 0 then
				return
			end

			if generate_autoload then
				local tmp_path = string.format('%s.%d~', autoload_path, uv.os_getpid())
				uv.fs_open(tmp_path, 'wx', 384, function(err, fd)
					assert(not err, err)
					local s = vim.inspect(autoload, { newline = '', indent = '' })
					s = string.format('return (%s)', s)
					uv.fs_write(fd, s, -1, function(err)
						assert(not err, err)
						uv.fs_close(fd, function(err, success)
							assert(not err, err)
							assert(success)
							uv.fs_rename(tmp_path, autoload_path, function(err, success)
								assert(not err, err)
								assert(success)
							end)
						end)
					end)
				end)
			end
		end)
	end

	Trace.trace(span)

	collectgarbage('restart')

	Trace.trace(setup_span)
end

return M
