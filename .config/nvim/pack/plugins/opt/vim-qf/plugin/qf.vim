if exists('#qf')
	finish
endif

command! -nargs=+ -bang -bar Qfile call qf#file([<f-args>], <bang>0)
command! -nargs=* -bang Qglobal call qf#global(<q-args>, <bang>0)
command! -nargs=* Qvglobal Qglobal! <args>
command! -nargs=? Qn call qf#n(<q-args>, <bang>0)
command! Qbuflisted call qf#buflisted()

augroup qf
	autocmd!
	autocmd QuickFixCmdPost l* ++nested silent! botright lwindow
	autocmd QuickFixCmdPost [^l]* ++nested if empty(getqflist()) | silent! cclose | else | botright copen | cfirst | endif
	autocmd QuitPre * ++nested silent! lclose | silent! cclose
augroup END
