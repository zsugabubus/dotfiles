autocmd BufRead,BufNewFile *
	\ if getline(1) =~# '\v^#!(/usr/bin/|/bin/|/usr/bin/env )dash>'|
	\   setfiletype sh|
	\ endif
