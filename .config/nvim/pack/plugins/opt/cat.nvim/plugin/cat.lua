local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

local autocmd = api.nvim_create_autocmd
local user_command = api.nvim_create_user_command

user_command('Cat', function(opts)
	local t = {}
	for _, arg in ipairs(opts.fargs) do
		for _, path in ipairs(fn.expand(arg, false, true)) do
			cmd.edit(fn.fnameescape(path))
			table.insert(t, fn.bufnr(path))
		end
	end
	cmd.edit('cat://' .. table.concat(t, ','))
end, { nargs = '+', complete = 'file', desc = 'Concat files' })

user_command('CatArgs', function(opts)
	local t = {}
	for _, arg in ipairs(vim.fn.argv()) do
		table.insert(t, fn.bufnr(arg))
	end
	cmd.edit('cat://' .. table.concat(t, ','))
end, { desc = 'Concat files of argument list' })

user_command('Narrow', function(opts)
	local buf = api.nvim_get_current_buf()
	cmd.edit(('cat://%d:%d-%d'):format(buf, opts.line1, opts.line2))
end, { range = 2, desc = 'Narrow buffer to the selected region' })

autocmd('BufReadCmd', {
	pattern = 'cat://*',
	callback = function(...)
		return require('cat').handle_read_autocmd(...)
	end,
})

autocmd('BufWriteCmd', {
	pattern = 'cat://*',
	callback = function(...)
		return require('cat').handle_write_autocmd(...)
	end,
})
