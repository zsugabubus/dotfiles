function! git#buf#read(cmd) abort
	nnoremap <buffer><nowait> q <C-w>c
	nnoremap <silent><buffer><nowait><expr> gu ':edit '.fnameescape(matchstr(expand('%'), '\v^git://[^:]*:([012]:)?.{-}\ze([^/]+/?)?$'))."\<CR>"
	nmap <silent><buffer><nowait> <CR> gf
	nmap <silent><buffer><nowait> u gu
	nnoremap <silent><buffer><nowait> ~ :call <SID>git_edit_rev('edit', '~'.v:count1)<CR>
	nnoremap <silent><buffer><nowait> ^ :call <SID>git_edit_rev('edit', '^'.v:count1)<CR>
	nnoremap <silent><buffer><nowait> - :call <SID>git_edit_rev('edit', '-'.v:count1)<CR>

	let b:git_buf_cmd = a:cmd
	setlocal buftype=nofile noswapfile undolevels=-1
	command! -buffer Gupdate call s:git_buf_update()

	Gupdate
endfunction

function! s:git_edit_rev(edit, mod) abort
	let [_, rev, path; _] = matchlist(expand('%'), '\v^git://([^:]*)(.*)$')
	let output = git#cmd#output('rev-parse', rev.a:mod)
	execute a:edit fnameescape('git://'.output[0].path)
endfunction

function! s:git_buf_update() abort
	let cmd = ['git', '--no-optional-locks'] + b:git_buf_cmd
	let viargs = cmd->map({_, x-> shellescape(x, 1)})->join(' ')

	let view = winsaveview()

	noautocmd setlocal noreadonly modifiable
	silent noautocmd call deletebufline(bufnr(), 1, '$')
	silent noautocmd execute '0read!' viargs
	silent noautocmd call deletebufline(bufnr(), '$')
	noautocmd setlocal readonly nomodifiable

	diffupdate

	call winrestview(view)

	filetype detect
endfunction
