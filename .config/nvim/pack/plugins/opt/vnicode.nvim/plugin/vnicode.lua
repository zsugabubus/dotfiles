local keymap = vim.api.nvim_set_keymap
local user_command = vim.api.nvim_create_user_command

keymap('', 'ga', '', {
	callback = function()
		require('vnicode.commands').ga()
	end,
})

keymap('', 'g8', '', {
	callback = function()
		require('vnicode.commands').g8()
	end,
})

user_command('Vnicode', function(...)
	require('vnicode.commands').view(...)
end, {
	nargs = '?',
	complete = function(...)
		return require('vnicode.commands').view_complete(...)
	end,
})

user_command('VnicodeInstall', function(...)
	require('vnicode.commands').install(...)
end, {
	nargs = '?',
	complete = function(...)
		return require('vnicode.commands').install_complete(...)
	end,
})

user_command('VnicodeUpdate', function(opts)
	require('vnicode.commands').update(opts)
end, {})
