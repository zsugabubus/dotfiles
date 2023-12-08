vim.api.nvim_set_keymap('n', '<Plug>(commenter)', '', {
	expr = true,
	callback = function()
		vim.o.operatorfunc = 'v:lua._commenter_operatorfunc'
		return 'g@'
	end,
})

vim.api.nvim_set_keymap('x', '<Plug>(commenter)', '', {
	expr = true,
	callback = function()
		vim.o.operatorfunc = 'v:lua._commenter_operatorfunc'
		return 'g@\n'
	end,
})

vim.api.nvim_set_keymap('n', '<Plug>(commenter-current-line)', '', {
	expr = true,
	replace_keycodes = true,
	callback = function()
		if vim.v.count == 0 then
			return '<Plug>(commenter)_'
		else
			return '<Plug>(commenter)j'
		end
	end,
})

function _G._commenter_operatorfunc()
	require('commenter').comment_lines(
		vim.api.nvim_buf_get_mark(0, '[')[1],
		vim.api.nvim_buf_get_mark(0, ']')[1]
	)
end
