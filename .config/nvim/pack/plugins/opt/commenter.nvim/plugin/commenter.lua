vim.api.nvim_set_keymap('n', '<Plug>(commenter-lines)', '', {
	expr = true,
	callback = function()
		vim.o.opfunc = 'v:lua._commenter_opfunc'
		return 'g@'
	end,
})

function _G._commenter_opfunc()
	require('commenter').comment_lines(
		vim.fn.getpos("'[")[2],
		vim.fn.getpos("']")[2]
	)
end
