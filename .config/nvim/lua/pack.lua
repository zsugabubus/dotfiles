local api = vim.api
local concat = table.concat
local find = string.find
local gmatch = string.gmatch
local gsub = string.gsub
local insert = table.insert
local ipairs = ipairs
local pcall = pcall
local sub = string.sub
local uv = vim.loop

local fs_access = uv.fs_access
local fs_scandir = uv.fs_scandir
local fs_scandir_next = uv.fs_scandir_next

local lua2path = {}

local function notify_error(...)
	local s = string.format(...)
	vim.schedule(function()
		vim.notify(s, vim.log.levels.ERROR)
	end)
end

local function noop()
	-- Do nothing.
end

local function list_dir(path)
	local handle = fs_scandir(path)
	if handle then
		return fs_scandir_next, handle
	end
	return noop
end

-- pack_plugin_dirs[name] = {package_dir}/pack/*/opt/{name}
local function find_package_plugins(package_dir, pack_plugin_dirs)
	local pack_dir = package_dir .. '/pack'
	for star, kind in list_dir(pack_dir) do
		if kind ~= 'file' then
			local opt_dir = pack_dir .. '/' .. (star .. '/opt')
			for name, kind in list_dir(opt_dir) do
				if kind ~= 'file' then
					local path = opt_dir .. '/' .. name
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
	if find(file, '.lua', -4, true) then
		ok, err = loadfile(file)
		if ok then
			ok, err = pcall(ok)
		end
	else
		ok, err = pcall(api.nvim_cmd, { cmd = 'source', args = { file } }, {})
	end
	if not ok then
		notify_error('Error detected while processing %s:\n%s', file, err)
	end

	trace(span)
end

local function source_dir(dir, trace)
	for name, kind in list_dir(dir) do
		local path = dir .. '/' .. name
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

	local dot = find(name, '.', 1, true)
	if not dot then
		return
	end
	local head = sub(name, 1, dot - 1)
	local path = lua2path[head]
	if path then
		local tail = sub(name, dot)
		local prefix = path .. gsub(tail, '%.', '/')

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
			notify_error('Plugin %s: %s() failed:\n%s', plugin.name, name, err)
		end
	end
end

local function add(opts)
	local trace = require('trace').trace

	local fn_span = trace('add plugins')

	local pack_plugin_dirs = {}
	local rtp_plugin_files = {}
	local rtp_before = {}
	local rtp_middle = {}
	local rtp_after = {}
	local source_files_before = {}
	local source_dirs_before = {}
	local source_dirs_after = {}

	local span = trace('find pack plugins')

	for package_dir in gmatch(api.nvim_get_option_value('packpath', {}), '[^,]+') do
		find_package_plugins(package_dir, pack_plugin_dirs)
	end

	local span = trace(span, 'find rtp plugins')

	for path in gmatch(api.nvim_get_option_value('runtimepath', {}), '[^,]+') do
		insert(rtp_middle, path)

		local plugin_dir = path .. '/plugin'
		for name in list_dir(plugin_dir) do
			if not rtp_plugin_files[name] then
				local path = plugin_dir .. '/' .. name
				rtp_plugin_files[name] = path
			end
		end
	end

	local span = trace(span, 'collect plugins')

	local plugins = {}
	for _, plugin in ipairs(opts) do
		if plugin.enabled ~= false then
			plugin.name = plugin[1]

			local plugin_dir = pack_plugin_dirs[plugin.name]
			if plugin_dir then
				insert(plugins, plugin)
				insert(rtp_before, plugin_dir)
				insert(source_dirs_before, plugin_dir .. '/plugin')

				local after_dir = plugin_dir .. '/after'
				if fs_access(after_dir, 'x') then
					insert(rtp_after, after_dir)
					insert(source_dirs_after, after_dir .. '/plugin')
				end
			else
				local plugin_file = rtp_plugin_files[plugin.name]
				if plugin_file then
					insert(plugins, plugin)
					insert(source_files_before, plugin_file)
				else
					notify_error('Plugin %s not found', plugin.name)
				end
			end
		end
	end

	local span = trace(span, 'before plugins')

	for _, plugin in ipairs(plugins) do
		local span = trace(plugin.name)
		plugin_hook(plugin, 'before')
		trace(span)
	end

	local span = trace(span, 'set runtimepath')

	local rtp = rtp_before
	for _, path in ipairs(rtp_middle) do
		insert(rtp, path)
	end
	for _, path in ipairs(rtp_after) do
		insert(rtp, path)
	end
	api.nvim_set_option_value('runtimepath', concat(rtp, ','), {})

	local span = trace(span, 'initialize plugins')

	if package.loaders[2] ~= package_loader then
		insert(package.loaders, 2, package_loader)
	end
	api.nvim_set_option_value('loadplugins', false, {})

	local lua_span = trace('initialize lua package cache')

	for _, plugin_dir in ipairs(rtp) do
		local lua_dir = plugin_dir .. '/lua'
		for name in list_dir(lua_dir) do
			local path = lua_dir .. '/' .. name
			lua2path[name] = path
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
		plugin_hook(plugin, 'after')
		trace(span)
	end

	trace(span)

	trace(fn_span)
end

return {
	add = add,
}
