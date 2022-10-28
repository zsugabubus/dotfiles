function! tilde#expand() abort
	if getcmdtype() !=# ':'
		return '/'
	endif

	let cmdpos = getcmdpos()
	let cmdline = getcmdline()

	" Only for file related operations.
	if cmdline !~# '\v^%((tab)?e%[dit]|r%[ead]|w%[rite]|[lt]?cd|(tab)?new|[tl]?cd|source|sp%[lit]|vs%[plit])>'
		return '/'
	endif

	let word_start = match(strpart(cmdline, -1, cmdpos), '\v.* \zs\~.*')
	if word_start < 0
		return '/'
	endif

	if &shell =~# 'zsh'
		let cmd = join([
			\  'set -eu',
			\  '. $ZDOTDIR/??-hashes*.zsh',
			\  'f=$~0',
			\  'unhash -dm \*',
			\  'print -D -- $f',
			\], "\n")
	endif

	let word = cmdline[word_start:cmdpos]
	let output = trim(system([&shell, '-c', cmd, word]))
	if v:shell_error
		throw 'vim-tilde: '.output
		return '/'
	endif

	return "\<C-\>e\"".escape(strpart(cmdline, 0, word_start).output.'/'.strpart(cmdline, cmdpos), '\"')."\"\<CR>"
endfunction
