local M = {}

function M.setup(opts)
	vim.api.nvim_set_keymap(
		'n',
		opts.keymap.leader,
		'<Plug>(commenter-lines)',
		{}
	)
	vim.api.nvim_set_keymap('n', opts.keymap.line, '', {
		expr = true,
		replace_keycodes = true,
		callback = function()
			if vim.v.count == 0 then
				return '<Plug>(commenter-lines)V0'
			else
				return '<Plug>(commenter-lines)Vj'
			end
		end,
	})
end

return M
