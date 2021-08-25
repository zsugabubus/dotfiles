" Show empty space after lines.
"
" Uses Whitespace highlight.

command! -nargs=? ShowEmptyAttachToBuffer lua require'showempty'.attach_to_buffer(<args>)
command! -nargs=? ShowEmptyDetachFromBuffer lua require'showempty'.detach_from_buffer(<args>)
command! -nargs=? ShowEmptyToggleOnBuffer lua
	\ local se = require'showempty'
	\ if se.is_buffer_attached(<args>) then
	\   se.detach_from_buffer(<args>)
	\ else
	\   se.attach_to_buffer(<args>)
	\ end
