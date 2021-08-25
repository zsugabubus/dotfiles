" Show indentation on empty lines.
command! -nargs=? ShowIndentAttachToBuffer lua require'showindent'.attach_to_buffer(<args>)
command! -nargs=? ShowIndentReattach lua require'showindent'.reattach(<args>)
command! -nargs=? ShowIndentDetachFromBuffer lua require'showindent'.detach_from_buffer(<args>)
command! -nargs=? ShowIndentToggleOnBuffer lua
		\	local si = require'showindent'
		\	if si.is_buffer_attached(<args>) then
		\		si.detach_from_buffer(<args>)
		\	else
		\		si.attach_to_buffer(<args>)
		\ end

augroup showindent
	autocmd!
	autocmd BufWinEnter * ShowIndentAttachToBuffer
	autocmd OptionSet expandtab,tabstop,shiftwidth,listchars ShowIndentReattach
augroup END
