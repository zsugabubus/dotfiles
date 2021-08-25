# vim-completecontacts

Complete mail contacts.

# Configuration
```vim
" Don't show nicknames next to addresses.
let g:completecontacts_hide_nicks=1

" Custom query command instead of mutt's `query_command`.
let g:completecontacts_query_cmd=
  \ "/usr/bin/abook --mutt-query '' |
  \ awk -F'\\t' 'NR > 1 {print $2\" <\"$1\">\"}' |
  \ fzy -e %s"
```
