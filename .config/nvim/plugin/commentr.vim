let commentr_leader = 'g'
let commentr_uncomment_map = ''

nmap gcD gcdO
nmap gcM gcmO
noremap <silent> gc :<C-U>unmap gc<CR>:packadd vim-commentr<CR>:call feedkeys('gc', 'i')<CR>
