local buffer = require('git.buffer')
local Revision = require('git.revision')

return function(opts)
	local source_buf = vim.api.nvim_get_current_buf()
	local source_win = vim.api.nvim_get_current_win()
	local source_file = vim.fn.expand('%:p')

	local rev, path = buffer.buf_get_rev(source_buf)
	if rev then
		rev, path = Revision.split_path(rev)
	else
		rev, path = '-', source_file
	end

	vim.cmd('topleft vsplit')

	local buf = vim.fn.bufnr(string.format('git-blame://%s:%s', rev, path), true)
	vim.bo[buf].buflisted = true
	vim.b[buf].git_related_win = source_win
	vim.cmd.buffer(buf)
end
