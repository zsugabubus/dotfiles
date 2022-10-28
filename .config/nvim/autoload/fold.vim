function! fold#foldtext() abort
	let right = ' ('.string(v:foldend - v:foldstart + 1).' lines)'
	let line = getline(nextnonblank(v:foldstart))
	let text = substitute(line, '\v^.{-}<(\w.{-})\s*%(\{\{\{.*)?$', '\1', '')
	let tw = min([(&tw > 0 ? &tw : 80), winwidth('%') - float2nr(ceil(log10(line('$')))) - 1])
	let left = repeat(' ', strdisplaywidth(matchstr(line, '\m^\s*')))
	let text = text.repeat(' ', tw - strdisplaywidth(left.text.right))
	return left.text.right.repeat(' ', 999)
endfunction
