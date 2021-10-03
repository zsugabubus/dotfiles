" Motion align text.
if !hasmapto('<Plug>(Mall)')
	vmap <silent><unique> gl <Plug>(Mall)
endif

silent! vnoremap <silent><unique> <Plug>(Mall) :<C-U>let mall_count = v:count<CR>:<C-U>set opfunc=mall#align<CR>g@

function s:skip_white_after(pat)
	return '/\m'.a:pat.'\s*\zs\s<CR>'
endfunction

for s:mapping in [
\  'vn',
\  'vN',
\  'v/',
\  'v?',
\  [':', s:skip_white_after(':')],
\  ['=', '/\m\s\?=<CR>'],
\  'f&',
\  [',', s:skip_white_after(',')],
\  'f\\',
\  'f<Tab>',
\  'f<Space>',
\  'f<bar>'
\]
	let [s:from, s:to] = type(s:mapping) ==# v:t_string
		\ ? [s:mapping[1:], s:mapping]
		\ : s:mapping
	execute 'silent! vmap <silent><unique> <Plug>(Mall)'.s:from.' <Plug>(Mall)'.s:to
endfor
