if vim.b.current_syntax then
	return
end
vim.b.current_syntax = 'tmuxlist'

vim.cmd([[
syn match tmuxIdentifier display /^tmux:\/\/[^ ]*\ze\t/
syn match tmuxText display /\t\zs.*/

hi default link tmuxIdentifier Identifier
hi default link tmuxText String
]])
