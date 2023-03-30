function! git#complete#glob(prefix, cmdline, pos, dirs_only) abort
	let wd = Git().wd
	let files = globpath(wd, a:prefix.'*', 0, 1)
	if a:dirs_only
		call filter(files, 'isdirectory(v:val)')
	endif
	let start = len(wd)
	return map(files, {_,x-> x[start:].(a:dirs_only || isdirectory(x) ? '/' : '')})
endfunction

function! git#complete#dir(prefix, cmdline, pos) abort
	return git#complete#glob(a:prefix, a:cmdline, a:pos, 1)
endfunction

function! git#complete#file(prefix, cmdline, pos) abort
	return git#complete#glob(a:prefix, a:cmdline, a:pos, 0)
endfunction
