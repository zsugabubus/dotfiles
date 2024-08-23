local api = vim.api

local keymap = api.nvim_set_keymap
local user_command = api.nvim_create_user_command

keymap('', '<Plug>(commenter)', '', {
	expr = true,
	callback = function()
		vim.o.operatorfunc = 'v:lua._commenter_operatorfunc'
		return 'g@'
	end,
})

keymap('n', '<Plug>(commenter-current-line)', '<Plug>(commenter)_', {})

function _G._commenter_operatorfunc()
	require('commenter').comment_lines(
		0,
		api.nvim_buf_get_mark(0, '[')[1],
		api.nvim_buf_get_mark(0, ']')[1]
	)
end

user_command('Comment', function(opts)
	require('commenter').comment_lines(0, opts.line1, opts.line2, true)
end, { range = 2 })

user_command('Uncomment', function(opts)
	require('commenter').comment_lines(0, opts.line1, opts.line2, false)
end, { range = 2 })
