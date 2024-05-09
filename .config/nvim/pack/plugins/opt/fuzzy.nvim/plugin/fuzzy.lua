vim.api.nvim_create_user_command('Fuzzy', function(opts)
	require('fuzzy')[opts.fargs[1]]()
end, { nargs = 1 })
