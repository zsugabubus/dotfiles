local keymap = vim.api.nvim_set_keymap

keymap('', 'f', '', {
	expr = true,
	callback = function()
		require('wtf').set_search('')
		return ';'
	end,
})

keymap('', 'F', '', {
	expr = true,
	callback = function()
		require('wtf').set_search('b')
		return ';'
	end,
})

keymap('', 't', '', {
	expr = true,
	callback = function()
		require('wtf').set_search('t')
		return ';'
	end,
})

keymap('', 'T', '', {
	expr = true,
	callback = function()
		require('wtf').set_search('tb')
		return ';'
	end,
})

keymap('', ';', '', {
	callback = function()
		require('wtf').repeat_search('')
	end,
})

keymap('', ',', '', {
	callback = function()
		require('wtf').repeat_search('b')
	end,
})
