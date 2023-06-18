local opts = {
	nowait = true,
	silent = true,
	noremap = true,
}

vim.api.nvim_buf_set_keymap(0, 'n', 'cb', 'Obreak<Esc>0', opts)

for c, s in
	string.gmatch('ppick rreword eedit ssquash ffixup ddrop', '([^ ])([^ ]+)')
do
	vim.api.nvim_buf_set_keymap(
		0,
		'',
		'c' .. c,
		string.format(':normal! 0ce%s<Esc>W', s),
		opts
	)
end

for c, s in
	string.gmatch('xexec llabel treset mmerge uupdate-ref', '([^ ])([^ ]*)')
do
	vim.api.nvim_buf_set_keymap(0, 'n', 'c' .. c, string.format('O%s ', s), opts)
end

vim.b.git_use_preview = true

for _, x in ipairs({ 'gf', '<CR>' }) do
	vim.api.nvim_buf_set_keymap(0, 'n', x, '', {
		nowait = true,
		callback = function()
			return require('git.buffer').goto_object()
		end,
	})
end
