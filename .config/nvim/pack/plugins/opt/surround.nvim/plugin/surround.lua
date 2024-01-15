local keymap = vim.api.nvim_set_keymap

keymap('v', '<Plug>(surround)c', '', {
	callback = function()
		local c = vim.fn.getcharstr()
		require('surround').surround_visual(c, c)
	end,
})

local function c(c)
	keymap('v', '<Plug>(surround)' .. c, '<Plug>(surround)c' .. c, {})
end

c('|')

keymap('v', '<Plug>(surround)<CR>', '', {
	callback = function()
		require('surround').surround_visual('\n', '\n', '', '')
	end,
})

local function quote(c)
	keymap('v', '<Plug>(surround)' .. c, '', {
		callback = function()
			local ccc = string.rep(c, 3)
			require('surround').surround_visual(c, c, ccc, ccc)
		end,
	})
end

quote("'")
quote('"')
quote('`')

local function parenthesis(open, close)
	keymap('v', '<Plug>(surround)' .. open, '', {
		callback = function()
			require('surround').surround_visual(open .. ' ', ' ' .. close)
		end,
	})
	keymap('v', '<Plug>(surround)' .. close, '', {
		callback = function()
			require('surround').surround_visual(open, close)
		end,
	})
end

parenthesis('(', ')')
parenthesis('[', ']')
parenthesis('{', '}')
parenthesis('<', '>')

keymap('v', '<Plug>(surround)<', '', {
	callback = function()
		local s = vim.fn.input('<')
		require('surround').surround_visual(
			string.format('<%s>', s),
			string.format('</%s>', s)
		)
	end,
})

keymap('n', '<Plug>(surround-delete)', '%%v%O<Esc>xgv<Left>o<Esc>xgvo<Esc>', {})
