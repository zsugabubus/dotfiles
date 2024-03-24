local group = vim.api.nvim_create_augroup('register', {})

vim.api.nvim_create_user_command('Register', function(opts)
	vim.cmd.edit(vim.fn.fnameescape('reg://' .. opts.args))
end, {
	nargs = '?',
})

vim.api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'reg://*',
	callback = function(opts)
		local regname = string.sub(opts.match, 7)
		local lines = vim.split(vim.fn.getreg(regname, 1, false), '\n')
		vim.api.nvim_buf_set_lines(opts.buf, 0, -1, true, lines)
	end,
})

vim.api.nvim_create_autocmd('BufWriteCmd', {
	group = group,
	pattern = 'reg://*',
	callback = function(opts)
		local regname = string.sub(opts.match, 7)
		local lines = vim.api.nvim_buf_get_lines(opts.buf, 0, -1, true)
		vim.fn.setreg(regname, table.concat(lines, '\n'))
		vim.bo[opts.buf].modified = false
		vim.api.nvim_echo({
			{
				string.format('Register %s written', regname),
				'Normal',
			},
		}, true, {})
	end,
})
