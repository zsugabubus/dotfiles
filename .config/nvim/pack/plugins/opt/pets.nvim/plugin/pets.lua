local group = vim.api.nvim_create_augroup('pets', {})

vim.api.nvim_create_autocmd('InsertEnter', {
	group = group,
	once = true,
	callback = function()
		require('pets')
	end,
})
