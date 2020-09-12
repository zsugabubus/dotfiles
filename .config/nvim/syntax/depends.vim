" Vim syntax file
" Language: package depends file
" Maintainer: zsugabubus

if exists("b:current_syntax")
  finish
endif

syn match dependName /^\S\+\>/ nextgroup=dependType
syn match dependType /\t.\+/ contained
syn match Comment /^#.*/

hi link dependName String
hi link dependType Keyword

let b:current_syntax="depends"
