if exists("b:did_ftplugin")
	finish
endif
let b:did_ftplugin = 1

map <buffer> <CR> I<space><Esc>ZZ
cmap <buffer><expr> <CR> (getcmdtype() ==# '/' ? "\<CR>\<CR>" : "\<CR>")
