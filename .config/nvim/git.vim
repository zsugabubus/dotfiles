set switchbuf=useopen,usetab
nnoremap <silent><expr> gf (0 <=# match(expand('<cfile>'), '\v^\x{4,}$') ? ':pedit git://'.fnameescape(expand('<cfile>'))."\<CR>" : 0 <=# match(expand('<cfile>'), '^[ab]/') ? 'viWof/lgf' : 'gf')

command! -nargs=* -range Gdiff call s:git_diff(<f-args>)
command! -nargs=* Gshow execute 'edit git://'.(empty(<q-args>) ? expand('<cword>') : <q-args>)
command! -nargs=* Gtree call s:git_tree(0, <f-args>)
command! -nargs=* Gtreediff call s:git_tree(1, <f-args>)
command! -nargs=* -range=% Glog
	\ if <line1> ==# 1 && <line2> ==# line('$')|
	\   enew|
	\   call termopen(['git', 'log-vim'] + [<f-args>])|
	\ else|
	\   vertical new|
	\   call s:git_pager(['log', '--follow', '-L<line1>,<line2>:'.expand('#')])|
	\ endif

function! s:git_pager_update(bufnr, cmdline, new) abort
	let blob = systemlist(['git'] + a:cmdline, [], 1)

	setlocal modifiable
	call setbufline(a:bufnr, 1, blob)
	call deletebufline(a:bufnr, line('$'), '$')
	setlocal readonly nomodifiable
	if a:new
		normal! gg}w
	endif

	filetype detect
endfunction

function! s:print_error(output) abort
	echohl Error
	for line in a:output
		echomsg line
	endfor
	echohl None
endfunction

function! s:git_edit_rev(edit, mod) abort
	let [_, rev, path; _] = matchlist(expand('%'), '\v^git://([^:]*)(.*)$')

	let output = systemlist(['git', '--no-optional-locks', 'rev-parse', rev.a:mod])
	if v:shell_error
		call s:print_error(output)
		return
	endif

	execute a:edit fnameescape('git://'.output[0].path)
endfunction

function! s:git_pager(cmdline) abort
	nnoremap <buffer><nowait> q <C-w>c
	nnoremap <silent><buffer><nowait><expr> gu ':edit '.fnameescape(matchstr(expand('%'), '\v^git://[^:]*:([012]:)?.{-}\ze([^/]+/?)?$'))."\<CR>"
	nmap <silent><buffer><nowait> u gu
	nnoremap <silent><buffer><nowait> go :e %<C-r><C-f><CR>
	nmap <silent><buffer><nowait> o go
	nmap <silent><buffer><nowait> <Return> go
	nnoremap <silent><buffer><nowait> ~ :call <SID>git_edit_rev('edit', '~'.v:count1)<CR>
	nnoremap <silent><buffer><nowait> ^ :call <SID>git_edit_rev('edit', '^'.v:count1)<CR>
	nnoremap <silent><buffer><nowait> - :call <SID>git_edit_rev('edit', '-'.v:count1)<CR>

	setlocal nobuflisted bufhidden=hide buftype=nofile noswapfile undolevels=-1

	autocmd ShellCmdPost,VimResume <buffer> call s:git_pager_update(expand('<abuf>'), a:cmdline, 0)
	call s:git_pager_update(bufnr(), a:cmdline, 1)
endfunction

function! s:git_tree(diff, ...) abort range
	let list = []
	let common_diff_options = ['--root', '-r']
	let W = '\v^[W/]$'
	let I = '\v^%(I|:|:0|0)$'
	if !a:0
		" Compare working tree and index against head.
		let cmd = ['status', '--porcelain']
	elseif a:1 =~# W && get(a:000, 2, 'I') =~# I " W [I]
		let cmd = ['diff-files'] + common_diff_options
	elseif a:1 =~# W && a:0 ==# 2 " W <tree>
		let cmd = ['diff-index'] + common_diff_options + [a:2]
	elseif a:1 =~# I " I [<tree>=HEAD]
		let cmd = ['diff-index', '--cached'] + common_diff_options + [get(a:000, 2, '@')]
	elseif a:0 ==# 2 && a:2 =~# I " <tree> I
		let cmd = ['diff-index', '--cached', '-R'] + common_diff_options + [a:1]
	elseif a:0 ==# 2 && a:2 =~# W " <tree> W
		let cmd = ['diff-index', '-R'] + common_diff_options + [a:1]
	else " <tree-1> [<tree-2>=<tree-1> parents]
		let cmd = ['diff-tree'] + common_diff_options + a:000
	endif
	let output = systemlist(['git', '--no-optional-locks'] + cmd)
	if v:shell_error
		call s:print_error(output)
		return
	endif

	call add(list, {
		\  'text': 'diff '.get(a:000, 1, '').' -> '.get(a:000, 2, ''),
		\})

	if cmd[0] ==# 'status'
		for change in output
			let [_, status, path; _] = matchlist(change, '\v^(..) (.*)$')
			call add(list, {
				\  'filename': path,
				\  'type': status,
				\  'text': '['.status.']',
				\})
		endfor
	elseif 0 < len(output)
		if output[0] =~# '\C^[0-9a-f]'
			let rev = 'git://'.output[0].':'
			let list = [{
				\  'filename': 'git://'.output[0],
				\  'text': '#'
				\}]
			unlet output[0]
		endif

		" To not affect layout.
		if a:diff
			cclose
		endif

		for change in output
			let [_, src_mode, dst_mode, src_hash, dst_hash, status, score, src_path, dst_path; _] = matchlist(change, '\C\v^:(\d{6}) (\d{6}) ([0-9a-f]{40}) ([0-9a-f]{40}) ([A-Z])(\d*)\t([^\t]+)(\t[^\t]+)?$')
			if src_hash =~# '\v^0{40}$'
				let src_hash = ''
			endif
			if dst_hash =~# '\v^0{40}$'
				let dst_hash = ''
			endif

			let filename = !empty(dst_path) ? dst_path : src_path
			let dst_bufname = (!empty(dst_hash) ? 'git://'.dst_hash.'/' : '').filename
			if a:diff
				let dst_bufnr = bufnr(dst_bufname, 1)
				execute '$tab' dst_bufnr 'sbuffer'
				set buflisted
				diffthis

				if !empty(src_hash)
					let src_bufname = 'git://'.src_hash.'/'.src_path
					let src_bufnr = bufnr(src_bufname, 1)
					execute 'vertical' src_bufnr 'sbuffer'
					diffthis
					wincmd H
				endif
			else
				let dst_bufnr = 0
			endif

			redraw

			call add(list, {
				\  'type': status,
				\  'bufnr': dst_bufnr,
				\  'module': filename,
				\  'filename': dst_bufname,
				\  'text': get({
				\    'A': 'new',
				\    'C': 'copied',
				\    'D': 'gone',
				\    'M': 'modified',
				\    'R': 'renamed',
				\    'T': 'type changed',
				\    'U': 'unmerged'
				\  }, status, '['.status.']').(!empty(dst_path) ? ' (renamed '.src_path.')' : '').(src_mode !=# dst_mode ? ' ('.src_mode.' -> '.dst_mode.')' : ''),
				\})
		endfor
	endif

	call setqflist(list)
	" Quickfix window is useless in diff mode.
	if a:diff
		0tab copen
		silent cfirst
	else
		copen
	endif
endfunction

function! s:git_diff(...) abort range
	let rev = get(a:000, 0, ':0')
	" ::./file -> :./file
	if rev ==# ':'
		let rev = ''
	endif
	diffthis
	execute 'vsplit git://'.fnameescape(rev).':./'.fnameescape(expand('%'))
	setlocal bufhidden=wipe
	autocmd BufUnload <buffer> diffoff
	diffthis
	wincmd p
	wincmd L
endfunction

function! s:git_ignore_stderr(chan_id, data, name) abort dict
endfunction

function! s:git_statusline_update() abort dict
	let self.status =
		\ (self.bare ? 'BARE:' : self.inside ? 'GIT_DIR:' : '').
		\ self.head.
		\ ("S"[!self.staged]).("M"[!self.modified]).("U"[!self.untracked]).
		\ (self.ahead || self.behind
		\    ? '{'.
		\      (self.ahead ? '+'.self.ahead : '').
		\      (self.behind ? (self.ahead ? '/' : '').'-'.self.behind : '')
		\    .'}'
		\    : '').
		\ (!empty(self.operation)
		\   ? ' ['.self.operation.(self.step ? ' '.self.step.'/'.self.total : '').']'
		\   : '')

	" So startup screen does not disappear. Eeerh.
	if 2 <# bufnr('$')
		redrawstatus!
	endif
endfunction

function! s:git_status_on_behind_ahead(chan_id, data, name) abort dict
	if len(a:data) <=# 1
		return
	endif
	let [_, self.git.behind, self.git.ahead; _] = matchlist(a:data[0], '\v^(\d+)\t(\d+)$')
	call call('s:git_statusline_update', [], self.git)
endfunction

function! s:git_status_on_head(chan_id, data, name) abort dict
	if len(a:data) <=# 1
		return
	endif
	let self.git.head = a:data[0]
	call call('s:git_statusline_update', [], self.git)
endfunction

function! s:git_status_on_status(chan_id, data, name) abort dict
	if len(a:data) <=# 1
		return
	endif
	let self.git.staged = 0 <=# match(a:data, '^\m[MARC]')
	let self.git.modified = 0 <=# match(a:data, '^\m.[MARC]')
	let self.git.untracked = 0 <=# match(a:data, '^\m\n??')
	call call('s:git_statusline_update', [], self.git)
endfunction

function! s:git_status_on_bootstrap(chan_id, data, name) abort dict
	if len(a:data) <=# 1
		return
	endif
	let [self.git.dir, self.git.bare, self.git.inside, self.git.head, cdup; _] = a:data + ['']
	let self.git.bare = self.git.bare ==# 'true'
	let self.git.inside = self.git.inside ==# 'true'
	" Ladies and gentlemen, we are fucked. This is how we can get top-level
	" directory with a single process call.
	let self.git.wd .= cdup

	let self.vcs = 'git'

	if !self.git.inside
		call jobstart(['git', '--no-optional-locks', '-C', self.git.wd, 'status', '--porcelain'], {
			\  'pty': 0,
			\  'stdout_buffered': 1,
			\  'stderr_buffered': 1,
			\  'on_stdout': function('s:git_status_on_status'),
			\  'on_stderr': function('s:git_ignore_stderr'),
			\  'git': self.git
			\})
	endif

	call jobstart(['git', '--no-optional-locks', '-C', self.git.wd, 'rev-list', '--count', '--left-right', '--count', '@{upstream}...@'], {
		\  'pty': 0,
		\  'stdout_buffered': 1,
		\  'stderr_buffered': 1,
		\  'on_stdout': function('s:git_status_on_behind_ahead'),
		\  'on_stderr': function('s:git_ignore_stderr'),
		\  'git': self.git
		\})

	" sequencer/todo
	if isdirectory(self.git.dir.'/rebase-merge')
		let self.git.operation = 'rebase'
		let self.git.head = readfile(self.git.dir.'/rebase-merge/head-name')[0]
		try
			let self.git.step = +readfile(self.git.dir.'/rebase-merge/msgnum')[0]
			let self.git.total = +readfile(self.git.dir.'/rebase-merge/end')[0]
		catch
			" Editing message.
		endtry
	elseif isdirectory(self.git.dir.'/rebase-apply')
		if file_readable(self.git.dir.'/rebase-apply/rebasing')
			let self.git.head = readfile(self.git.dir.'/rebase-merge/head-name')[0]
			let self.git.operation = 'rebase'
		elseif file_readable(self.git.dir.'/rebase-apply/applying')
			let self.git.operation = 'am'
		else
			let self.git.operation = 'am/rebase'
		endif
		try
			let self.git.step = +readfile(self.git.dir.'/rebase-apply/next')[0]
			let self.git.total = +readfile(self.git.dir.'/rebase-apply/last')[0]
		catch
			" Editing message.
		endtry
	elseif file_readable(self.git.dir.'/MERGE_HEAD')
		let self.git.operation = 'merge'
	elseif file_readable(self.git.dir.'/CHERRY_PICK_HEAD')
		let self.git.operation = 'cherry-pick'
	elseif file_readable(self.git.dir.'/REVERT_HEAD')
		let self.git.operation = 'revert'
	elseif file_readable(self.git.dir.'/BISECT_LOG')
		let self.git.operation = 'bisect'
	endif

	if self.git.head ==# 'HEAD'
		" Detached.
		call jobstart(['git', '--no-optional-locks', '-C', self.git.wd, 'name-rev', '--name-only', self.git.head], {
			\  'pty': 0,
			\  'stdout_buffered': 1,
			\  'stderr_buffered': 1,
			\  'on_stdout': function('s:git_status_on_head'),
			\  'on_stderr': function('s:git_ignore_stderr'),
			\  'git': self.git
			\})
	endif

	let self.git.head = substitute(self.git.head, '^refs/heads/', '', '')

	call call('s:git_statusline_update', [], self.git)
endfunction

" git --no-optional-locks rev-list --walk-reflogs --count refs/stash
" /usr/share/git/git-prompt.sh
function! Git() abort
	let dir = getcwd()
	if !has_key(s:git, dir)
		let s:git[dir] = {
			\  'vcs': '',
			\  'dir': '',
			\  'wd': dir.'/',
			\  'inside': 0,
			\  'staged': 0,
			\  'modified': 0,
			\  'untracked': 0,
			\  'behind': 0,
			\  'ahead': 0,
			\  'operation': '',
			\  'step': 0,
			\  'total': 0,
			\  'status': ''
			\}
		call jobstart(['git', '--no-optional-locks', '-C', dir, 'rev-parse', '--abbrev-ref', '--absolute-git-dir', '--is-bare-repository', '--is-inside-git-dir', '@', '--show-cdup'], {
			\  'pty': 0,
			\  'stdout_buffered': 1,
			\  'stderr_buffered': 1,
			\  'on_stdout': function('s:git_status_on_bootstrap'),
			\  'on_stderr': function('s:git_ignore_stderr'),
			\  'git': s:git[dir]
			\})
	endif
	return s:git[dir]
endfunction

augroup vimrc_git
	autocmd!

	let s:git = {}
	autocmd ShellCmdPost,TermLeave,VimResume * let s:git = {}

	" Alsa reset cache when away for a longer time.
	autocmd FocusLost * let s:git_last_focused = localtime()
	autocmd FocusGained *
		\ if localtime() - s:git_last_focused > 5 * 60|
		\   let s:git = {}|
		\ endif|
		\ unlet s:git_last_focused

	autocmd BufReadCmd git://* ++nested
		\ call s:git_pager([
		\   'show',
		\   '--compact-summary',
		\   '--patch',
		\   '--format=format:commit %H%nparent %P%ntree %T%nref: %D%nAuthor: %aN <%aE>%nDate:   %aD%nCommit: %cN <%cE>%n%n    %s%n%-b%n',
		\   matchstr(expand("<amatch>"), '\v://\zs[^:/]*%(:.*)?')
		\ ])

	" Highlight conflict markers.
	autocmd Colorscheme * match ErrorMsg '^\(<\|=\|>\)\{7\}\([^=].\+\)\?$'
augroup END
