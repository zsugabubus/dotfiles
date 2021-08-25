" Complete Contacts

let s:save_cpo = &cpo
set cpo&vim

if !has_key(g:, 'completecontacts_hide_nicks')
  let g:completecontacts_hide_nicks=0
endif
if !has_key(g:, 'completecontacts_query_cmd')
  let g:completecontacts_query_cmd=
    \ system((executable('neomutt') ? 'neomutt' : 'mutt') . ' -Q query_command')[15:-2]
endif

setl completeopt+=menu,menuone,noinsert completefunc=CompleteContacts

inoremap <Plug>(CompleteContacts) <C-X><C-U>

" Purpose: Return contacts matching to `base'.
function! s:getContacts(base) abort
  let cmd=substitute(g:completecontacts_query_cmd, '%s', shellescape(trim(a:base)), '')
  return split(system(cmd), '\n')
endfunction

" Purpose: Contact completion function
function! CompleteContacts(findstart, base) abort
  if a:findstart
    return searchpos('\v[,:]\s?\ze', 'nbeW', line('.'))[1]
  else
    return {
    \   'words': map(s:getContacts(a:base),
    \     {_, contact-> {
    \       'word': g:completecontacts_hide_nicks
    \                 ? trim(matchlist(contact, '\v^(.+)\<(.{-})\>$')[2])
    \                 : contact,
    \       'abbr': contact
    \     }}),
    \   'refresh': 'always'
    \ }
  endif
endfunction

" Autocomplete as typing.
augroup AutoCompleteContacts
  autocmd!
  autocmd InsertCharPre * noautocmd if getline('.') =~ '\v\c^(cc|bcc|to):'
  \ |   call feedkeys("\<C-X>\<C-U>", 'i')
  \ | endif
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set ts=2 sw=2 et:
