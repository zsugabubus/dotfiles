local api = vim.api

local autocmd = api.nvim_create_autocmd
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('register', {})

user_command('Register', function(opts)
	vim.cmd.edit(vim.fn.fnameescape('reg://' .. opts.args))
end, { nargs = '?' })

autocmd('BufReadCmd', {
	group = group,
	pattern = 'reg://*',
	callback = function(opts)
		local regname = opts.match:sub(7)
		local lines = vim.split(vim.fn.getreg(regname, 1, false), '\n')
		api.nvim_buf_set_lines(opts.buf, 0, -1, true, lines)
		vim.bo.modeline = false
	end,
})

autocmd('BufWriteCmd', {
	group = group,
	pattern = 'reg://*',
	callback = function(opts)
		local regname = opts.match:sub(7)
		local lines = api.nvim_buf_get_lines(opts.buf, 0, -1, true)
		vim.fn.setreg(regname, table.concat(lines, '\n'))
		vim.bo.modified = false
		local s = ('Register %s written'):format(regname)
		api.nvim_echo({ { s, 'Normal' } }, false, {})
	end,
})
