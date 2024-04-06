local keymap = vim.api.nvim_set_keymap

local empty = {}

local function set_search(lhs, flags)
	keymap('', lhs, '', {
		expr = true,
		replace_keycodes = true,
		callback = function()
			require('wtf').set_search(flags)
			return '<Plug>(wtf-repeat)'
		end,
	})
end

set_search('<Plug>(wtf-f)', '')
set_search('<Plug>(wtf-F)', 'b')
set_search('<Plug>(wtf-t)', 't')
set_search('<Plug>(wtf-T)', 'tb')

local function repeat_search(lhs, flags)
	keymap('', lhs, '', {
		callback = function()
			require('wtf').repeat_search(flags)
		end,
	})
end

repeat_search('<Plug>(wtf-repeat)', '')
repeat_search('<Plug>(wtf-repeat-opposite)', 'b')

local function nxo(lhs, rhs)
	keymap('n', lhs, rhs, empty)
	keymap('x', lhs, rhs, empty)
	keymap('o', lhs, rhs, empty)
end

nxo('f', '<Plug>(wtf-f)')
nxo('F', '<Plug>(wtf-F)')
nxo('t', '<Plug>(wtf-t)')
nxo('T', '<Plug>(wtf-T)')
nxo(';', '<Plug>(wtf-repeat)')
nxo(',', '<Plug>(wtf-repeat-opposite)')
