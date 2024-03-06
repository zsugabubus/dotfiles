local keymap = vim.api.nvim_set_keymap

local function char(lhs, opts)
	keymap('', lhs, '', {
		expr = true,
		callback = function()
			vim.o.operatorfunc = 'v:lua._align_operatorfunc'

			function _G._align_operatorfunc()
				opts.start_lnum = vim.api.nvim_buf_get_mark(0, '[')[1]
				opts.end_lnum = vim.api.nvim_buf_get_mark(0, ']')[1]
				require('align').align(opts)
			end

			return 'g@'
		end,
	})
end

char('<Plug>(align)=', {
	pattern = '[=+-/*%<>!?^&|.]*=',
	align = 'right',
})

char('<Plug>(align),', {
	char = ',',
	margin = { 0, 1 },
	align = 'left',
})

char('<Plug>(align):', {
	char = ':',
	margin = { 0, 1 },
	align = 'right',
	count = 1,
})

char('<Plug>(align)|', {
	char = '|',
	align = 'right',
})
