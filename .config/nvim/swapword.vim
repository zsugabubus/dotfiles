" Swap word word.
nnoremap <silent> Sw ciw<Esc>wviwp`^Pb

" Swap WORD WORD.
nnoremap <silent> SW  = ciW<Esc>wviWp`^PB

" Swap xxx = yyy.
nnoremap <expr> S= ":call feedkeys(\"_vt=BEc\\<LT>Esc>wwv$F,f;F;hp`^P\", 'nt')\<CR>"
