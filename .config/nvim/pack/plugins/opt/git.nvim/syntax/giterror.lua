if vim.b.current_syntax then
	return
end
vim.b.current_syntax = 'giterror'

vim.cmd.syntax([[match gitError display /\v^(fatal|error):.*/]])

vim.api.nvim_set_hl(0, 'gitError', {
	default = true,
	link = 'ErrorMsg',
})
