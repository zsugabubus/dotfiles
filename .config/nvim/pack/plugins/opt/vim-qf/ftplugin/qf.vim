setlocal modifiable nolist
nnoremap <expr><silent><buffer> dd ":<C-u>call setqflist(filter(getqflist(), 'v:key!=".(line('.') - 1)."'))<CR>:.".(line('.') - 1)."<CR>"
nnoremap <silent><buffer> df :<C-u>call setqflist(filter(getqflist(), 'v:val.bufnr!='.getqflist()[line('.') - 1].bufnr))<CR>
nnoremap <silent><buffer> <C-o> :colder<CR>
nnoremap <silent><buffer> <C-i> :cnewer<CR>
