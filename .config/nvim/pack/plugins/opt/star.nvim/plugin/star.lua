local keymap = vim.api.nvim_set_keymap

local empty = {}

keymap('', '<Plug>(star-word-forward)', '', {
	callback = function()
		require('star').search('w')
	end,
})

keymap('', '<Plug>(star-word-backward)', '', {
	callback = function()
		require('star').search('wb')
	end,
})

keymap('', '<Plug>(star-forward)', '', {
	callback = function()
		require('star').search('')
	end,
})

keymap('', '<Plug>(star-backward)', '', {
	callback = function()
		require('star').search('b')
	end,
})

local function nxo(lhs, rhs)
	keymap('n', lhs, rhs, empty)
	keymap('x', lhs, rhs, empty)
	keymap('o', lhs, rhs, empty)
end

nxo('*', '<Plug>(star-word-forward)')
nxo('#', '<Plug>(star-word-backward)')
nxo('g*', '<Plug>(star-forward)')
nxo('g#', '<Plug>(star-backward)')
