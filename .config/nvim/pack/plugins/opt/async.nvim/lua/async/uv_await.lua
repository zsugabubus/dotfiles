local a = require('async')
return setmetatable({}, {
	__index = function(M, uv_fn)
		M[uv_fn] = function(...)
			return a.await(a.uv[uv_fn](...))
		end
		return M[uv_fn]
	end,
})
