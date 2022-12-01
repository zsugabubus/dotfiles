local M = {}

local function autoload(lib)
	M[lib] = setmetatable({}, {
		__index = function(_, key)
			M[lib] = require ('async.' .. lib)
			return M[lib][key]
		end
	})

end

autoload('uv')
autoload('uv_await')

function M.imm(...)
	local args = {...}
	return function(ready)
		return ready(unpack(args))
	end
end

function M.future(async_fn, ...)
	assert(async_fn)
	local args = {...}
	return function(ready)
		table.insert(args, ready)
		assert(async_fn(unpack(args)))
	end
end

local function mux(futures, wait_all)
	return function(ready)
		local function cancel()
			for key, cancel in pairs(futures) do
				if type(cancel) == 'function' then
					-- Cancel must call callback.
					cancel()
				end
			end
		end

		local done, n, threshold = 0, 0, math.huge
		for key, future in pairs(futures) do
			n = n + 1
			futures[key] = future(function(...)
				local result = {...}
				futures[key] = result
				done = done + 1
				-- Ensure that ready is not called synchronously here.
				if threshold <= done then
					cancel()
					if done == n then
						return ready(futures)
					end
				end
				return result
			end)
		end
		threshold = wait_all and n or 1

		-- Now check whether future has been resolved synchronously.
		if threshold <= done then
			cancel()
			if done == n then
				return ready(futures)
			end
		else
			return cancel
		end
	end
end

function M.race(futures)
	return mux(futures, false)
end

function M.all(futures)
	return mux(futures, true)
end

function M.await(future)
	local thread = coroutine.running()
	local result = future(function(...)
		if coroutine.status(thread) == 'suspended' then
			return assert(coroutine.resume(thread, ...))
		end
		return {...}
	end)
	-- nil: `ready` to be called asynchronously.
	-- function: Same as nil but can be canceled.
	-- table: `ready` has been called synchronously.
	if type(result) == 'table' then
		return unpack(result)
	else
		return coroutine.yield(result)
	end
end

function M.await_race(futures)
	return M.await(M.race(futures))
end

function M.await_all(futures)
	return M.await(M.all(futures))
end

function M.async_do(fn, ...)
	local thread = coroutine.create(fn)
	return assert(coroutine.resume(thread, ...))
end

return M
