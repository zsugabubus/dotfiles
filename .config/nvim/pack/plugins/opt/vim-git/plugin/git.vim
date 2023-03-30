if exists('loaded_git')
	finish
endif
let loaded_git = 1

" /usr/share/git/git-prompt.sh
let g:git_symbols = "SMUT"
let g:git_symbols = "+*%$"
let g:git_max_tabs = 15

nnoremap <silent><expr> gf (
	\   match(expand('<cfile>'), '\v^\x{4,}$') >= 0
	\ ? ':pedit git://'.fnameescape(expand('<cfile>'))."\<CR>"
	\ : match(expand('<cfile>'), '^[ab]/') >= 0
	\ ? 'viWof/lgf'
	\ : match(expand('%'), 'git://') >= 0
	\ ? ':edit '.fnameescape(expand('%').(0 <= stridx(expand('%')[6:], ':') ? '' : ':').expand('<cfile>'))."\<CR>"
	\ : 'gf')

function! s:git_register_file_command(name, complete) abort
	execute printf(
		\ "command! -bang -complete=customlist,git#complete#%s -nargs=? G%s ".
		\ "execute '%s<bang> '.substitute(simplify(fnamemodify(fnameescape(Git().cdup.<q-args>), ':.')), '^$', '.', '')",
		\ a:complete, a:name, a:name)
endfunction

for s:cmd in ['cd', 'lcd', 'tcd']
	call s:git_register_file_command(s:cmd, 'dir')
endfor

for s:cmd in ['e', 'tabe', 'sp', 'vs']
	call s:git_register_file_command(s:cmd, 'file')
endfor

for s:cmd in ['gr', 'grep', 'lgr', 'lgrep', 'grepa', 'lgrepa']
	execute printf("command! -nargs=* -bang G%s call git#grep#do(':%s<bang> --column '.<q-args>)", s:cmd, s:cmd)
endfor

function! Git(...)
	return call('git#status#update', a:000)
endfunction

function! GitBuffer() abort
	let name = expand('%:h')
	if !empty(name)
		return Git(name)
	else
		return Git()
	endif
endfunction

command! Gcancel call s:git_cancel()
command! -nargs=* Gshow execute 'edit git://'.(empty(<q-args>) ? expand('<cword>') : <q-args>)
command! -complete=file -nargs=* -range=% Glog call git#log#open(<line1>, <line2>, <range>, [<f-args>])
command! -nargs=* Gtree call git#tree#open(0, <f-args>)
command! -nargs=* Gtreediff call git#tree#open(1, <f-args>)
command! -nargs=* -range Gdiff call git#diff#open(<f-args>)
command! -nargs=* -range=% Gblame call git#blame#open(<line1>, <line2>, <range>, [<f-args>])
for [s:git_cmd, s:cmd] in [['Gconflicts', 'laddexpr'], ['Gcconflicts', 'caddexpr']]
	execute "command! ".s:git_cmd." noautocmd g/^=======$/".s:cmd." expand('%').':'.line('.').':'.getline('.')|doautocmd QuickFixCmdPost ".s:cmd
endfor

augroup git
	autocmd!

	autocmd BufReadCmd git://* ++nested
		\ call git#buf#read([
		\   'show',
		\   '--compact-summary',
		\   '--patch',
		\   '--stat-width='.winwidth(0),
		\   '--format=format:commit %H%nparent %P%ntree %T%nref: %D%nAuthor: %aN <%aE>%nDate:   %aD%nCommit: %cN <%cE>%n%n    %s%n%-b%n',
		\   matchstr(expand("<amatch>"), '\v://\zs.*')
		\ ])

	" Highlight conflict markers.
	autocmd Colorscheme * match ErrorMsg '^\(<\|=\|>\)\{7\}\([^=].\+\)\?$'
augroup END

function! s:git_status_flush() abort
	let g:git = {}
endfunction

augroup git_status
	autocmd!

	call s:git_status_flush()
	autocmd ShellCmdPost,FileChangedShellPost,VimResume * call s:git_status_flush()
	autocmd TermLeave * if expand('<amatch>') =~# '\vterm:.*:.*(sh|git)>'|call s:git_status_flush()|endif
augroup END
