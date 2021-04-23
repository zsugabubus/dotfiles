if exists("b:current_syntax")
	finish
endif

let b:current_syntax = "typelanguage"

" syn match Comment '\v#\x+'
" syn match Identifier '\v[a-zA-Z]+\ze:'
syn match Constant '\v#\x{8}>'
" syn keyword Type int true long string bytes '#'
syn match Type '\v<([a-z]*\.)*[A-Z][a-zA-Z]*>'
syn match number '\v<\d{1,2}>'

