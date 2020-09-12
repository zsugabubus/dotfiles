if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim

let &equalprg='sort -dbfuk2 -k1'
setlocal tabstop=16 shiftwidth=16 softtabstop=16 noexpandtab
let b:undo_ftplugin = "
  \ setlocal tabstop< shiftwidth< softtabstop< expandtab< textwidth<"

let &cpo = s:save_cpo
unlet s:save_cpo
