local api = vim.api
local bo = vim.bo

local group = api.nvim_create_augroup('capture', {})

api.nvim_create_user_command('Capture', function(opts)
	if opts.args == '' then
		opts.args = 'messages'
	end
	vim.cmd.edit(vim.fn.fnameescape('output://' .. opts.args))
end, {
	complete = 'command',
	nargs = '*',
})

api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'output://*',
	callback = function(opts)
		local src = string.sub(opts.match, 10)
		local output = api.nvim_exec2(src, { output = true }).output
		api.nvim_buf_set_lines(0, 0, -1, false, vim.split(output, '\n'))
		bo.buftype = 'nofile'
		bo.readonly = true
		bo.swapfile = false
		bo.modeline = false
	end,
})
