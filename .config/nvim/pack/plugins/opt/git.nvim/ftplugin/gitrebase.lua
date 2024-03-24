local keymap = vim.api.nvim_buf_set_keymap

local opts = {
	nowait = true,
	silent = true,
	noremap = true,
}

vim.b.git_use_preview = true

local function change_command(lhs, command)
	keymap(
		0,
		'',
		'c' .. lhs,
		string.format(':normal! 0ce%s<Esc>W', command),
		opts
	)
end

change_command('d', 'drop')
change_command('e', 'edit')
change_command('f', 'fixup')
change_command('p', 'pick')
change_command('r', 'reword')
change_command('s', 'squash')

for _, x in ipairs({ 'gf', '<CR>' }) do
	keymap(0, 'n', x, '', {
		nowait = true,
		callback = function()
			return require('git.buffer').goto_object()
		end,
	})
end
