vim.api.nvim_set_keymap('n', '<Plug>(commenter)', '', {
	expr = true,
	callback = function()
		vim.o.opfunc = 'v:lua._commenter_opfunc'
		return 'g@'
	end,
})

vim.api.nvim_set_keymap('n', '<Plug>(commenter-current-line)', '', {
	expr = true,
	replace_keycodes = true,
	callback = function()
		if vim.v.count == 0 then
			return '<Plug>(commenter)V0'
		else
			return '<Plug>(commenter)Vj'
		end
	end,
})

function _G._commenter_opfunc()
	require('commenter').comment_lines(
		vim.api.nvim_buf_get_mark(0, '[')[1],
		vim.api.nvim_buf_get_mark(0, ']')[1]
	)
end
