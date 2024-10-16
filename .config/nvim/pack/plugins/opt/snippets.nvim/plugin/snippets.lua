vim.api.nvim_create_autocmd('InsertEnter', {
	callback = function(...)
		require('snippets')._handle_insert_enter(...)
		return true
	end,
})
