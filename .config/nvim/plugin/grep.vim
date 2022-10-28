set grepprg=noglob\ rg\ --vimgrep\ --smart-case
set grepformat=%f:%l:%c:%m

command! -nargs=* GREP execute 'grep ' substitute(<q-args> =~ '\v^''|%(^|\s)-\w' ? <q-args> : shellescape(<q-args>, 1), '<bar>', '\\<bar>', 'g')|redraw
Ccabbrev gr 'GREP'

command! TODO GREP \b(TODO|FIXME|BUG|WTF)\b.*:

xnoremap // y:GREP -F '<C-r>=@"<CR>'<CR>
