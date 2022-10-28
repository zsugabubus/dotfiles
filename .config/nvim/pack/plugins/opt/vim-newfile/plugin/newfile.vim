if exists('loaded_newfile')
	finish
endif
let loaded_newfile = 1

augroup newfile_shebang
	autocmd! BufNewFile * autocmd FileType <buffer> ++once call newfile#shebang()
augroup END

augroup newfile_mkdir
	autocmd! BufNewFile * autocmd BufWritePre <buffer> ++once call newfile#mkdir()
augroup END

augroup newfile_chmod
	autocmd! BufNewFile * autocmd BufWritePost <buffer> ++once call newfile#chmod()
augroup END
