local keymap = vim.api.nvim_set_keymap

keymap('', '*', '', {
	callback = function()
		require('star').search('w')
	end,
})

keymap('', '#', '', {
	callback = function()
		require('star').search('wb')
	end,
})

keymap('', 'g*', '', {
	callback = function()
		require('star').search('')
	end,
})

keymap('', 'g#', '', {
	callback = function()
		require('star').search('b')
	end,
})
