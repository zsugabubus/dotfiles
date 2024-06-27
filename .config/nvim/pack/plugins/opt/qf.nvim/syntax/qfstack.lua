if vim.b.current_syntax then
	return
end
vim.b.current_syntax = 'qfstack'

vim.cmd([[
syn match qfBufferName display /^qf:\/\/[^\t]*\ze\t/
syn match qfTitle display /\t\zs.*/

hi def link qfBufferName Identifier
hi def link qfTitle String
]])
