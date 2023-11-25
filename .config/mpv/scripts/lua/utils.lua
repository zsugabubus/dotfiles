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

local function buf_put_human_keys(buf, t)
	local first = true
	local prev

	for k in pairs(t) do
		assert(type(k) == 'string')
		if prev then
			if not first then
				buf:put(', ')
				first = false
			end
			buf:putf("'%s'", prev)
		end
		prev = k
	end

	if prev then
		if not first then
			buf:put(' or ', prev)
		end
		buf:putf("'%s'", prev)
	else
		buf:putf('(nothing)')
	end
end

function M.register_script_messages(name, registry)
	mp.register_script_message(name, function(command, ...)
		command = string.gsub(command, '-', '_')
		local fn = registry[command]

		if not fn then
			local buf = require('string.buffer').new()
			buf:putf("Invalid argument to 'script-messge %s'.", name)
			buf:putf(" Got '%s', expected ", command)
			buf_put_human_keys(buf, registry)
			buf:put(". (Note that '_' and '-' are not distinguished.)")
			mp.msg.warn(buf:tostring())
			return
		end

		fn(...)
	end)
end

function M.shesc(s)
	return string.format("'%s'", string.gsub(s, "'", [['"'"']]))
end

M.script_opts = mp.command_native({ 'expand-path', '~~/script-opts' })

function M.do_script_opt(name)
	local utils = require('mp.utils')
	local ok, content = pcall(dofile, utils.join_path(M.script_opts, name))
	if ok then
		return content
	end
end

return M
