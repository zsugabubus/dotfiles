if exists('b:current_syntax')
	finish
endif

let b:current_syntax = 'bsdlog'
setl nolist number norelativenumber

syn match bsdlogErr display '\m^<3>.*\(\n<c>.*\)*'
syn match bsdlogWarning display '\m^<4>.*\(\n<c>.*\)*'
syn match bsdlogInfo display '\m^<6>.*\(\n<c>.*\)*'

hi def bsdlogErr ctermfg=1 guifg=#ff0000 cterm=bold
hi def bsdlogWarning ctermfg=5 guifg=#ff00ff
hi def bsdlogInfo ctermfg=4 guifg=#0000ff
