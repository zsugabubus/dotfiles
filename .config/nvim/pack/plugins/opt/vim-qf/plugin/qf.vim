command! -nargs=+ -bang -bar Qfile call qf#file([<f-args>], <bang>0)
command! -nargs=+ -bang Qglobal call qf#global(<q-args>, <bang>0)
command! -nargs=+ Qvglobal Qglobal! <args>
