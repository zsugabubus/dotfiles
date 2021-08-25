if exists("b:current_syntax")
  finish
endif

syntax include @C syntax/c.vim

syntax region funcArg matchgroup=Snip start='^  #.*\zs(' end=')' contains=@C
syntax region stackVar matchgroup=Snip start='^    \w\zs' end='$' keepend contains=@C

let b:current_syntax = 'debugger-stack'
