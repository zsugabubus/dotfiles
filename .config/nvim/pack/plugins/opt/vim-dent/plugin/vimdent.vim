" Automatically configure indentation options. Requires no configuration.
if exists('#vim_dent')
	finish
endif

augroup vim_dent
	autocmd!
	autocmd BufReadPost * autocmd BufEnter <buffer=abuf> ++once silent call vimdent#Detect()
	autocmd BufNewFile * autocmd BufWritePost <buffer=abuf> ++once silent call vimdent#Detect()
augroup END
