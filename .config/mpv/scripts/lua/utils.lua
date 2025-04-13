local M = {}

function M.reduce_bool(b, action)
	if type(action) == 'boolean' then
		return b
	elseif action == 'toggle' then
		return not b
	elseif action == 'show' then
		return true
	elseif action == 'hide' then
		return false
	else
		mp.msg.warn(
			"Invalid action '%s', expected 'show', 'hide' or 'toggle'",
			action
		)
		return b
	end
end

function M.register_script_messages(name, registry)
	local function get_command_values()
		local t = {}
		for k in pairs(registry) do
			table.insert(t, k)
		end
		table.sort(t)
		return table.concat(t, ', ')
	end

	mp.register_script_message(name, function(command, ...)
		if not command then
			mp.msg.error(
				('Missing %s command, possible values: %s.'):format(
					name,
					get_command_values()
				)
			)
			return
		end

		command = command:gsub('-', '_')
		local fn = registry[command]

		if not fn then
			mp.msg.error(
				('Invalid %s command %s, possible values: %s.'):format(
					name,
					command,
					get_command_values()
				)
			)
			return
		end

		fn(...)
	end)
end

M.script_opts = mp.command_native({ 'expand-path', '~~/script-opts' })

function M.read_lua_options(name)
	local utils = require('mp.utils')
	local ok, content = pcall(dofile, utils.join_path(M.script_opts, name))
	if ok then
		return content
	end
end

return M
