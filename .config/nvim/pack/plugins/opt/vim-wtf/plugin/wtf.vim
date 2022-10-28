" Word t/f.
" - If pattern is lowercase, stop only at the beginning of words (snake_case/PascalCase).
" - Do not to stop at end-of-line.
if exists('loaded_ft')
	finish
endif
let loaded_ft = 1

noremap <silent> , <Cmd>call wtf#search(0)<CR>
noremap <silent> ; <Cmd>call wtf#search(1)<CR>
for s:letter in ['f', 'F', 't', 'T']
	execute printf("noremap <expr><silent> %s [setcharsearch({'forward': %d, 'until': %d, 'char': getcharstr()}), '<Cmd>call wtf#search(1)\<CR>'][1]",
		\ s:letter, s:letter =~# '\l', s:letter =~? 't')
endfor
