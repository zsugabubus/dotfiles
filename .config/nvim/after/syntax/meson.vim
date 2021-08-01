" Fucks working:
" syn clear mesonString
"
" Hack:
syn clear
unlet! b:current_syntax
source /usr/share/vim/vimfiles/syntax/meson.vim

syn region  mesonString
      \ start="\z('\)" end="\z1" skip="\\\\\|\\\z1"
      \ contains=@mesonVariable,mesonEscape,@Spell
syn region  mesonString
      \ start="\z('''\)" end="\z1" keepend
      \ contains=@mesonVariable,mesonEscape,mesonSpaceError,@Spell

syn cluster mesonVariable contains=mesonVariable,mesonVariableError

syn match   mesonVariableError
      \ display "@[^@]*@" contained
syn match   mesonVariable
      \ display "@\v%(%(BUILD|SOURCE)_ROOT|%(PRIVATE_|OUT|CURRENT_SOURCE_)DIR|DEPFILE|%(PLAIN|BASE)NAME|%(OUT|IN)PUT\d*|EXTRA_ARGS|\d+)\@" contained

hi def link mesonVariable PreProc
hi def link mesonVariableError Error
