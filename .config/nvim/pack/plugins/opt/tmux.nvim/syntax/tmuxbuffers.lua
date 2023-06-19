if vim.b.current_syntax then
	return
end
vim.b.current_syntax = 'tmuxbuffers'

vim.cmd([[
syn match tmuxIdentifier display /^tmux:\/\/[^ ]*\ze\t/
syn match tmuxBufferSample display /\t\zs.*/

hi default link tmuxIdentifier Identifier
hi default link tmuxBufferSample String
]])
