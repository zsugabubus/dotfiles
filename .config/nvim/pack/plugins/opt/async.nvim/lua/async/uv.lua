local uv = require 'luv'
local M = setmetatable({}, {
	__index = function(M, uv_fn)
		assert(type(uv[uv_fn]) == 'function')
		M[uv_fn] = function(...)
			return M.future(uv[uv_fn], ...)
		end
		return M[uv_fn]
	end,
})

function M.future(uv_fn, ...)
	local args = {...}
	return function(ready)
		table.insert(args, ready)
		local req = assert(uv_fn(unpack(args)))
		return function()
			pcall(uv.cancel, req)
		end
	end
end

function M.timer(timeout)
	return function(ready)
		local timer = uv.new_timer()
		timer:start(timeout, 0, ready)
		return function()
			timer:stop()
			ready('ECANCELED')
		end
	end
end

function M.assert(...)
	if select('#', ...) == 2 then
		local err, data = ...
		assert(not err, err)
		return data
	else
		local t = ...
		for key, result in pairs(t) do
			t[key] = M.assert(unpack(result))
		end
		return t
	end
end

function M.read_all(stream, into)
	uv.read_start(stream, function(err, data)
		assert(not err, err)
		if data then
			table.insert(into, data)
		end
	end)
end

function M.popen(args, ready)
	local stdout = uv.new_pipe()
	local stderr = uv.new_pipe()

	local stdout_buf, stderr_buf = {}, {}

	local argv0, argv = (function(argv0, ...)
		return argv0, {...}
	end)(unpack(args))

	local handle = uv.spawn(argv0, {
		stdio = {nil, stdout, stderr},
		args = argv,
	}, function(code, signal)
		if code == 0 and signal == 0 then
			ready(nil, table.concat(stdout_buf))
		else
			local err
			if signal == 0 then
				err = string.format('Program terminated with exit status %d', code)
			else
				err = string.format('Program received signal %d', signal)
			end
			ready(err, table.concat(stderr_buf))
		end
	end)

	M.read_all(stdout, stdout_buf)
	M.read_all(stderr, stderr_buf)

	return handle
end

return M
