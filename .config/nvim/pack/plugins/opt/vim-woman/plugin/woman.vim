" A better man.
if exists('#woman')
	finish
endif

silent! nnoremap <silent><unique> gm :Man<space>
silent! nnoremap <silent><unique> gM :Man<space><C-r><C-w><CR>
