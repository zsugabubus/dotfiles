local api = vim.api

local autocmd = api.nvim_create_autocmd
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('undowizard', {})

user_command('Undotree', function()
	vim.cmd('vsplit undotree://' .. api.nvim_get_current_buf())
end, {})

user_command('Undodiff', function(opts)
	vim.cmd(
		('leftabove vsplit undo://%d/%d | diffthis | wincmd p | diffthis'):format(
			api.nvim_get_current_buf(),
			opts.fargs[1] or '0'
		)
	)
end, { nargs = '?' })

autocmd('BufReadCmd', {
	group = group,
	pattern = 'undotree://*',
	callback = function(...)
		require('undowizard').read_undotree_autocmd(...)
	end,
})

autocmd('BufReadCmd', {
	group = group,
	pattern = 'undo://*',
	callback = function(...)
		require('undowizard').read_undo_autocmd(...)
	end,
})
