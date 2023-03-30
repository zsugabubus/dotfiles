setlocal nomodeline
setlocal norelativenumber nonumber

command! -buffer GblameCommit call git#blame#width(' ')
command! -buffer GblameAuthor call git#blame#width(' \d\{4}-')
command! -buffer GblameDate call git#blame#width(' \+\d\+) ')
command! -buffer GblameInfo call git#blame#width(') ')

nmap <nowait><silent><buffer> <CR> gf
nmap <nowait><silent><buffer> [ :call git#blame#jump('b')<CR>

nmap <nowait><silent><buffer> ] :call git#blame#jump('')<CR>
nmap <nowait><silent><buffer> c :GblameCommit<CR>
nmap <nowait><silent><buffer> a :GblameAuthor<CR>
nmap <nowait><silent><buffer> d :GblameDate<CR>
nmap <nowait><silent><buffer> i :GblameInfo<CR>
