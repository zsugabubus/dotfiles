local M = setmetatable({}, {
	__index = function(self, key)
		return require 'cword'[key]
	end,
})

vim.api.nvim_create_user_command('CwordEnable', function()
	M.toggle(true)
end, {})

vim.api.nvim_create_user_command('CwordDisable', function()
	M.toggle(false)
end, {})

vim.api.nvim_create_user_command('CwordToggle', function()
	M.toggle()
end, {})
