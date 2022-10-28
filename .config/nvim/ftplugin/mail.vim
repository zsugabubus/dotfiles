setlocal wrap ts=4 et spell

nnoremap <buffer><silent> gs gg/\C^Subject: \?\zs<CR>:noh<CR>vg_<C-G>
nnoremap <buffer><silent> gb gg}
