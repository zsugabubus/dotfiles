setmetatable(vim.health, {
	__index = function(t, k)
		setmetatable(t, { __index = require('wellness') })
		return t[k]
	end,
})
