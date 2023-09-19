local group = vim.api.nvim_create_augroup('capture', {})

vim.api.nvim_create_user_command('Capture', function(opts)
	if opts.args == '' then
		opts.args = 'messages'
	end
	vim.cmd.edit(vim.fn.fnameescape('output://' .. opts.args))
end, {
	complete = 'command',
	nargs = '*',
})

vim.api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'output://*',
	callback = function(opts)
		local src = string.sub(opts.match, 10)
		local output = vim.api.nvim_exec2(src, {
			output = true,
		}).output
		vim.api.nvim_buf_set_lines(opts.buf, 0, -1, false, vim.split(output, '\n'))
		local bo = vim.bo[opts.buf]
		bo.buftype = 'nofile'
		bo.readonly = true
		bo.swapfile = false
	end,
})
