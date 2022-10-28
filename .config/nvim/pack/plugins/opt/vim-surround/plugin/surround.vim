if exists('loaded_surround')
	finish
endif
let loaded_surround = 1

if !hasmapto('<Plug>(SurroundDelete)')
	nmap ds <Plug>(SurroundDelete)
endif
if !hasmapto('<Plug>(Surround)')
	xmap s <Plug>(Surround)
endif

nmap <silent> <Plug>(SurroundDelete) %%v%O<Esc>xgv<Left>o<Esc>xgvo<Esc>
xnoremap <silent><expr> <Plug>(Surround)" mode() ==# 'V' ? 'c"""<CR><C-r><C-o>""""<Esc>' : 'c"<C-r><C-o>""<Esc>'
xnoremap <silent><expr> <Plug>(Surround)' mode() ==# 'V' ? 'c''''''<CR><C-r><C-o>"''''''<Esc>' : 'c''<C-r><C-o>"''<Esc>'
xnoremap <silent><expr> <Plug>(Surround)` mode() ==# 'V' ? 'c```<CR><C-r><C-o>"```<Esc>' : 'c`<C-r><C-o>"`<Esc>'
xnoremap <silent><expr> <Plug>(Surround)> mode() ==# 'V' ? 'c<<CR><C-r><C-o>"><Esc>' : 'c<<C-r><C-o>"><Esc>'
xnoremap <silent><expr> <Plug>(Surround)< substitute('c<%><C-r><C-o>"</%><Esc>', '%', input('<'), 'g')
xnoremap <silent><expr> <Plug>(Surround)c substitute('c%<C-r><C-o>"%<Esc>', '%', getcharstr(), 'g')
xmap <Plug>(Surround)<space> <Plug>(Surround)c<space>
xmap <Plug>(Surround)<bar> <Plug>(Surround)c<bar>
xmap <Plug>(Surround)<CR> <Plug>(Surround)c<CR>
for [s:left, s:right] in [['(', ')'], ['[', ']'], ['{', '}']]
	execute "xnoremap <silent> <expr> <Plug>(Surround)".s:right." mode() ==# 'V' ? 'c".s:left."<CR><C-r><C-o>\"".s:right."<Esc>' : 'c".s:left."<C-r><C-o>\"".s:right."<Esc>'"
	execute "xnoremap <silent> <expr> <Plug>(Surround)".s:left."  mode() ==# 'V' ? 'c".s:left."<CR><C-r><C-o>\"".s:right."<Esc>' : line('.') ==# line('v') ? 'c".s:left." <C-r><C-o>\" ".s:right."<Esc>' : 'c".s:left."<C-r><C-o>\"".s:right."<Esc>'"
endfor
