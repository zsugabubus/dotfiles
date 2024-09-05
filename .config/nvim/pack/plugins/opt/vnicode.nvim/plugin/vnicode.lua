local api = vim.api

local autocmd = api.nvim_create_autocmd
local keymap = api.nvim_set_keymap
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('vnicode', {})

keymap('', '<Plug>(vnicode-inspect)', '', {
	callback = function()
		require('vnicode').inspect()
	end,
})

user_command('VnicodeInspect', function(opts)
	vim.cmd.edit(vim.fn.fnameescape('vnicode://' .. opts.args))
end, { nargs = '*' })

user_command('VnicodeView', function(...)
	require('vnicode').view_cmd(...)
end, {
	nargs = '?',
	complete = "custom,v:lua.require'vnicode'.view_complete",
})

user_command('VnicodeInstall', function(...)
	require('vnicode').install_cmd(...)
end, {
	nargs = '?',
	complete = "custom,v:lua.require'vnicode'.install_complete",
})

user_command('VnicodeUpdate', function(...)
	require('vnicode').update_cmd(...)
end, {})

autocmd('BufReadCmd', {
	group = group,
	pattern = 'vnicode://*',
	nested = true,
	callback = function(...)
		require('vnicode').read_vnicode_autocmd(...)
	end,
})
