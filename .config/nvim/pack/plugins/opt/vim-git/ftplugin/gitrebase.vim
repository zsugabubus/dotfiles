for s:cmd in split('pick reword edit squash fixup drop merge', ' ')
	execute printf('noremap <silent><buffer><nowait> c%s :normal! 0ce%s<Esc>w', s:cmd[0], s:cmd)
endfor

for s:cmd in split('llabel treset mmerge bbreak', ' ')
	execute printf('nnoremap <buffer><nowait> c%s cc%s ', s:cmd[0], s:cmd[1:])
endfor
