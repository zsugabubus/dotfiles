map <nowait><silent><buffer> [ :call search('\m^@@ ', 'bW')<CR>
map <nowait><silent><buffer> ] :call search('\m^@@ ', 'W')<CR>
map <nowait><silent><buffer> ( [
map <nowait><silent><buffer> ) ]
map <nowait><silent><buffer> { :call search('\m^diff ', 'bW')<CR>zt
map <nowait><silent><buffer> } :call search('\m^diff ', 'W')<CR>zt
noremap <nowait><silent><buffer> <space> <C-d>
