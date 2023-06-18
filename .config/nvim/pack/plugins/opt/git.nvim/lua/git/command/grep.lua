return function(cmd, opts)
	local saved_grepprg = vim.bo.grepprg
	local saved_grepformat = vim.go.grepformat

	vim.bo.grepprg = 'git grep --column'
	vim.go.grepformat = '%f:%l:%c:%m'

	local ok, err =
		pcall(vim.cmd[cmd], { args = { opts.args }, bang = opts.bang })
	-- Avoid hit enter prompt.
	vim.cmd.redraw()

	vim.bo.grepprg = saved_grepprg
	vim.go.grepformat = saved_grepformat

	if not ok then
		error(err)
	end
end
