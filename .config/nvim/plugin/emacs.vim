cnoremap <C-a> <Home>
cnoremap <C-b> <Left>
cnoremap <C-e> <End>
cnoremap <C-f> <Right>
cnoremap <C-n> <Down>
cnoremap <C-p> <Up>
cnoremap <C-v> <C-f>
cnoremap <M-b> <C-Left>
cnoremap <M-f> <C-Right>

inoremap <C-a> <C-o>_
inoremap <C-e> <C-o>g_<Right>

nnoremap <silent> <M-l> :lnext<CR>:silent! normal! zOzz<CR>
nnoremap <silent> <M-L> :lprev<CR>:silent! normal! zOzz<CR>
nnoremap <silent> <M-n> :cnext<CR>:silent! normal! zOzz<CR>
nnoremap <silent> <M-N> :cprev<CR>:silent! normal! zOzz<CR>
nnoremap <silent> <M-f> :next<CR>
nnoremap <silent> <M-F> :prev<CR>
