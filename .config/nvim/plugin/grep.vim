set grepprg=noglob\ rg\ --vimgrep\ --smart-case
set grepformat=%f:%l:%c:%m

command! -nargs=* GREP execute 'grep ' escape(<q-args> =~ '\v(^| )-[a-z]|[''''"]$' ? <q-args> : shellescape(<q-args>, 1), '<bar>#')|redraw
Ccabbrev gr 'GREP'

command! TODO GREP \b(TODO|FIXME|BUG|WTF)\b.*:

xnoremap // y:GREP -F <C-r>=shellescape(@", 1)<CR><CR>
