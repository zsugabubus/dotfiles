autocmd BufRead,BufNewFile *
	\ if getline(1) =~# '^<\d>'|
	\   setfiletype bsdlog|
	\ endif
