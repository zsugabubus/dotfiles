function! newfile#shebang() abort
	if changenr() !=# 0 || empty(&filetype)
		return
	endif

	let interpreter = get({
	\ 'javascript': 'node',
	\ 'python': 'python3',
	\}, &filetype, &filetype)

	call setline(1, interpreter->exepath()->substitute('.\+', "#!\\0\n\n", '')->split("\n"))
	normal! G
endfunction

function! newfile#mkdir() abort
	call mkdir(expand("<afile>:p:h"), 'p')
endfunction

function! newfile#chmod() abort
	if getline(1)[:1] ==# '#!'
		silent! call system(['chmod', '+x', '--', expand('<afile>:p')])
	endif
endfunction
