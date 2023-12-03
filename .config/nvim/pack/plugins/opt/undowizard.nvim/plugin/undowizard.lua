local api = vim.api

local group = api.nvim_create_augroup('undowizard', {})

api.nvim_create_user_command('Undotree', function()
	vim.cmd('vsplit undotree://' .. api.nvim_get_current_buf())
end, {})

api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'undotree://*',
	callback = function(...)
		require('undowizard').read_undotree(...)
	end,
})

api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'undo://*',
	callback = function(...)
		require('undowizard').read_undo(...)
	end,
})
