" Motion align text.
if !hasmapto('<Plug>(Mall)')
	vmap <silent><unique> gl <Plug>(Mall)
endif

silent! vnoremap <silent><unique> <Plug>(Mall) :<C-U>let mall_count = v:count<CR>:<C-U>set opfunc=mall#align<CR>g@

" Align non-whitespace after pattern.
function s:a(pat)
	return '/\m'.a:pat.'\s*\zs\s<CR>'
endfunction

for s:pec in ['vn', 'vN', 'v/', 'v?', [':', s:a(':')], ['=', '/\m\s\?=<CR>'], 'f&', [',', s:a(',')], 'f\\', 'f<Tab>', 'f<Space>', 'f<bar>']
	let [s:from, s:to] = type(s:pec) ==# v:t_string ? [s:pec[1:], s:pec] : s:pec
	execute 'silent! vmap <silent><unique> <Plug>(Mall)'.s:from.' <Plug>(Mall)'.s:to
endfor
