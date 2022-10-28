if exists('#qf')
	finish
endif

command! -nargs=+ -bang -bar Qfile call qf#file([<f-args>], <bang>0)
command! -nargs=+ -bang Qglobal call qf#global(<q-args>, <bang>0)
command! -nargs=+ Qvglobal Qglobal! <args>

augroup qf
	autocmd!
	autocmd QuickFixCmdPost l* ++nested silent! botright lwindow
	autocmd QuitPre * ++nested silent! lclose | silent! cclose
augroup END
