function! s:normal_star(wordbounds) abort
	let m = matchlist(getline('.'), '\v(\k*)%'.col('.').'c(\k+)|%'.col('.').'c[^[:keyword:]]*(\k+)')
	if empty(m)
		echohl Error
		echo 'No string under cursor.'
		echohl None
		return ''
	endif
	return '/\V'.(a:wordbounds ? '\<' : '').escape(m[1].m[2].m[3], '\/').(a:wordbounds ? '\>' : '').
		\(!empty(m[1])
			\? '/'.(strlen(m[1]) < strlen(m[2].m[3])
				\? 's+'.(strlen(m[1]))
				\: 'e-'.(strlen(m[2].m[3]) - 1))
			\: '')."\<CR>"
endfunction
nnoremap <expr> *  <SID>normal_star(1)
nnoremap <expr> #  <SID>normal_star(1).'NN'
nnoremap <expr> g* <SID>normal_star(0)
nnoremap <expr> g# <SID>normal_star(0).'NN'

xnoremap <expr> *  'y/<C-r>='."'\\V\\<'.escape(@\", '\\/').'\\>'\<CR>".'/e<CR>'
xnoremap <expr> #  'y/<C-r>='."'\\V\\<'.escape(@\", '\\/').'\\>'\<CR>".'/e<CR>'
xnoremap <expr> g* 'y/<C-r>='."'\\V'.escape(@\", '\\/')\<CR>".'/e<CR>'
xnoremap <expr> g# 'y?<C-r>='."'\\V'.escape(@\", '\\?')\<CR>".'?e<CR>'
