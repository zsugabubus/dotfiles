local api = vim.api
local ipairs = ipairs
local string_find = string.find
local string_format = string.format
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_sub = string.sub
local table_insert = table.insert
local type = type
local uv = vim.loop

local lua2path = {}

local function echo_error(...)
	api.nvim_echo({
		{ 'pack: ', 'ErrorMsg' },
		{ string_format(...), 'ErrorMsg' },
	}, true, {})
end

local function dir_empty()
	-- Do nothing.
end

local function dir(path)
	local handle = uv.fs_scandir(path)
	if handle then
		return uv.fs_scandir_next, handle
	end
	return dir_empty
end

-- pack_plugin_dirs[name] = {package_dir}/pack/*/opt/{name}
local function find_package_plugins(package_dir, pack_plugin_dirs)
	local pack_dir = package_dir .. '/pack'
	for star, kind in dir(pack_dir) do
		if kind ~= 'file' then
			local opt_dir = string_format('%s/%s/opt', pack_dir, star)
			for name, kind in dir(opt_dir) do
				if kind ~= 'file' then
					local path = string_format('%s/%s', opt_dir, name)
					if not pack_plugin_dirs[name] then
						pack_plugin_dirs[name] = path
					end
				end
			end
		end
	end
end

local function source_file(file, trace)
	local span = trace('source ' .. file)

	local ok, err
	if string_sub(file, -4) == '.lua' then
		ok, err = loadfile(file)
		if ok then
			ok, err = pcall(ok)
		end
	else
		ok, err = pcall(api.nvim_cmd, { cmd = 'source', args = { file } }, {})
	end
	if not ok then
		echo_error('Error detected while processing %s:\n%s', file, err)
	end

	trace(span)
end

local function source_dir(path, trace)
	for name, kind in dir(path) do
		local path = string_format('%s/%s', path, name)
		if kind == 'directory' then
			source_dir(path, trace)
		else
			source_file(path, trace)
		end
	end
end

local function package_loader(name)
	-- :h require()
	local path = lua2path[name .. '.lua']
	if path then
		local code = loadfile(path)
		if code then
			return code
		end
	end

	local path = lua2path[name]
	if path then
		local code = loadfile(path .. '/init.lua')
		if code then
			return code
		end
	end

	local dot = string_find(name, '.', 1, true)
	if not dot then
		return
	end
	local head = string_sub(name, 1, dot - 1)
	local path = lua2path[head]
	if path then
		local tail = string_sub(name, dot)
		local prefix = path .. string_gsub(tail, '%.', '/')

		local code = loadfile(prefix .. '.lua')
		if code then
			return code
		end

		local code = loadfile(prefix .. '/init.lua')
		if code then
			return code
		end
	end
end

local function plugin_hook(plugin, name)
	local fn = plugin[name]
	if fn then
		local ok, err = pcall(fn, plugin)
		if not ok then
			echo_error('Plugin %s: %s() failed:\n%s', plugin.name, name, err)
		end
	end
end

local function plugin_main_setup(plugin)
	local opts = plugin.opts
	if type(opts) == 'function' then
		opts = opts()
	end
	require(plugin.main).setup(opts)
end

local function plugin_setup(plugin)
	if plugin.opts == nil then
		return
	end

	if not plugin.main then
		echo_error(
			'Plugin %s specified opts but main is unset (maybe not a Lua plugin)',
			plugin.name
		)
		return
	end

	local ok, err = pcall(plugin_main_setup, plugin)
	if not ok then
		echo_error(
			'Plugin %s: require(%s).setup({opts}) failed:\n%s',
			plugin.name,
			vim.inspect(plugin.main),
			err
		)
	end
end

local function setup(opts)
	local trace = require('trace').trace

	local setup_span = trace('setup')

	local pack_plugin_dirs = {}
	local rtp_plugin_files = {}
	local rtp_before = {}
	local rtp_middle = {}
	local rtp_after = {}
	local source_files_before = {}
	local source_dirs_before = {}
	local source_dirs_after = {}
	local path2plugin = {}

	local span = trace('find pack plugins')

	for package_dir in
		string_gmatch(api.nvim_get_option_value('packpath', {}), '[^,]+')
	do
		find_package_plugins(package_dir, pack_plugin_dirs)
	end

	local span = trace(span, 'find rtp plugins')

	for path in
		string_gmatch(api.nvim_get_option_value('runtimepath', {}), '[^,]+')
	do
		table_insert(rtp_middle, path)

		local plugin_dir = path .. '/plugin'
		for name in dir(plugin_dir) do
			if not rtp_plugin_files[name] then
				local path = string_format('%s/%s', plugin_dir, name)
				rtp_plugin_files[name] = path
			end
		end
	end

	local span = trace(span, 'add plugins')

	local plugins = {}
	for _, plugin in ipairs(opts) do
		if plugin and plugin.enabled ~= false then
			plugin.name = plugin[1]

			local plugin_dir = pack_plugin_dirs[plugin.name]
			if plugin_dir then
				table_insert(rtp_before, plugin_dir)
				table_insert(source_dirs_before, plugin_dir .. '/plugin')
				path2plugin[plugin_dir] = plugin

				local after_dir = plugin_dir .. '/after'
				if uv.fs_access(after_dir, 'x') then
					table_insert(rtp_after, after_dir)
					table_insert(source_dirs_after, after_dir .. '/plugin')
					path2plugin[after_dir] = plugin
				end
			else
				local plugin_file = rtp_plugin_files[plugin.name]
				if plugin_file then
					table_insert(source_files_before, plugin_file)
				else
					echo_error('Plugin %s not found', plugin.name)
					goto not_found
				end
			end

			table_insert(plugins, plugin)

			plugin_hook(plugin, 'before')
		end
		::not_found::
	end

	local span = trace(span, 'set &runtimepath')

	local rtp = rtp_before
	for _, path in ipairs(rtp_middle) do
		table_insert(rtp, path)
	end
	for _, path in ipairs(rtp_after) do
		table_insert(rtp, path)
	end
	api.nvim_set_option_value('runtimepath', table.concat(rtp, ','), {})

	local span = trace(span, 'initialize plugins')

	table_insert(package.loaders, 2, package_loader)
	api.nvim_set_option_value('loadplugins', false, {})

	local lua_span = trace('initialize lua package cache')

	for _, plugin_dir in ipairs(rtp) do
		local plugin = path2plugin[plugin_dir]
		local lua_dir = plugin_dir .. '/lua'
		local main, main2 = not plugin or plugin.main
		for name, kind in dir(lua_dir) do
			local path = string_format('%s/%s', lua_dir, name)
			lua2path[name] = path
			if not main then
				if kind == 'directory' then
					if not main2 or uv.fs_access(path .. '/init.lua', 'r') then
						main2 = name
					end
				else
					main = string_sub(name, 1, -5)
				end
			end
		end
		if plugin then
			plugin.main = main or main2
		end
	end

	trace(lua_span)

	for _, file in ipairs(source_files_before) do
		source_file(file, trace)
	end
	for _, dir in ipairs(source_dirs_before) do
		source_dir(dir, trace)
	end
	for _, dir in ipairs(source_dirs_after) do
		source_dir(dir, trace)
	end

	local span = trace(span, 'after plugins')

	for _, plugin in ipairs(plugins) do
		local span = trace(plugin.name)
		plugin_setup(plugin)
		plugin_hook(plugin, 'after')
		trace(span)
	end

	trace(span)

	trace(setup_span)
end

return {
	setup = setup,
}
