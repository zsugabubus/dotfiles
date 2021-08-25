set switchbuf=useopen,usetab
nnoremap <silent><expr> gf (0 <=# match(expand('<cfile>'), '\v^\x{4,}$') ? ':pedit git://'.fnameescape(expand('<cfile>'))."\<CR>" : 0 <=# match(expand('<cfile>'), '^[ab]/') ? 'viWof/lgf' : 'gf')

command! -nargs=* -range Gdiff call s:git_diff(<f-args>)

function! s:git_dir_complete(prefix, cmdline, pos) abort
	let wd = Git().wd
	return map(filter(globpath(wd, a:prefix.'*', 1, 1), 'isdirectory(v:val)'), 'v:val['.len(wd).':]."/"')
endfunction

for s:cd in ['cd', 'lcd', 'tcd']
	execute "command! -complete=customlist,<SID>git_dir_complete -nargs=? G".s:cd." execute '".s:cd." '.fnameescape(Git().wd.<q-args>)"
endfor
command! -nargs=* Gshow execute 'edit git://'.(empty(<q-args>) ? expand('<cword>') : <q-args>)
command! -nargs=* Gtree call s:git_tree(0, <f-args>)
command! -nargs=* Gtreediff call s:git_tree(1, <f-args>)
command! -nargs=* -range=% Glog
	\ if <line1> ==# 1 && <line2> ==# line('$')|
	\   enew|
	\   nmap <silent><buffer><nowait> K k<Return>|
	\   nmap <silent><buffer><nowait> J j<Return>|
	\   call termopen(['git', 'log-vim'] + [<f-args>])|
	\ else|
	\   vertical new|
	\   call s:git_pager(['log', '-L<line1>,<line2>:'.expand('#')])|
	\ endif

function! s:git_pager_update(bufnr, cmdline, new) abort
	if has('nvim')
		let blob = systemlist(['git'] + a:cmdline, [], 1)

		setlocal modifiable
		call setbufline(a:bufnr, 1, blob)
		call deletebufline(a:bufnr, line('$'), '$')
		setlocal readonly nomodifiable
		if a:new
			" So CTRL-O immediately takes back to the previous commit.
			keepjump normal! gg}w
		endif

		filetype detect
	else
		let b:git_job = job_start(['git'] + a:cmdline, { 'in_io': 'null', 'out_io': 'buffer', 'out_buf': a:bufnr, 'out_modifiable': 0 })
	endif
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

	if has('nvim')
		let output = systemlist(['git', '--no-optional-locks', 'rev-parse', rev.a:mod])
	else
		let output = systemlist('git --no-optional-locks rev-parse '.shellescape(rev.a:mod))
	endif
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
	if has('nvim')
		let output = systemlist(['git', '--no-optional-locks'] + cmd)
	else
		let output = systemlist('git --no-optional-locks'.join(map(copy(cmd), {_,x-> ' '.shellescape(x)}), ''))
	endif
	if v:shell_error
		call s:print_error(output)
		return
	endif

	" call add(list, {
	" 	\  'text': 'status of '.join(a:000, ' '),
	" 	\})

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
	execute 'vsplit git://'.fnameescape(rev).':./'.fnamemodify(fnameescape(expand('%')), ':.')
	setlocal bufhidden=wipe
	autocmd BufUnload <buffer> diffoff
	diffthis
	wincmd p
	wincmd L
endfunction

function! s:git_ignore_stderr(chan_id, data, name) abort dict
endfunction

let s:git_jobs = {}

function! s:git_vim_close_cb(ch) abort
	let output = []
	while ch_status(a:ch, { 'part': 'out' }) ==# 'buffered'
		let output += [ch_read(a:ch)]
	endwhile
	let process = job_info(ch_getjob(a:ch)).process
	let [job, cb, git] = s:git_jobs[process]
	unlet s:git_jobs[process]
	if output ==# ['']
		return
	endif
	call call(function(cb), [output], git)
endfunction

function! s:git_nvim_on_stdout(chan_id, data, name) abort dict
	call call(self.cb, [a:data], self.git)
endfunction

function! s:git_run(git, cb, ...)
	if has('nvim')
		call jobstart(['git'] + a:000, {
			\  'pty': 0,
			\  'stdout_buffered': 1,
			\  'stderr_buffered': 1,
			\  'on_stdout': function('s:git_nvim_on_stdout'),
			\  'on_stderr': function('s:git_ignore_stderr'),
			\  'git': a:git,
			\  'cb': a:cb
			\})
	else
		let job = job_start(['git'] + a:000, { 'in_io': 'null', 'out_io': 'pipe', 'err_io': 'null', 'close_cb': function('s:git_vim_close_cb') })
		let s:git_jobs[job_info(job).process] = [job, a:cb, a:git]
	endif
endfunction

function! s:git_statusline_update() abort dict
	let self.status =
		\ (self.bare ? 'BARE:' : '').
		\ self.head.
		\ ("S"[!self.staged]).("M"[!self.modified]).("U"[!self.untracked]).
		\ (self.ahead ># 0 || self.behind ># 0
		\  ? (self.behind ? '<'.(self.behind ># 1 ? self.behind : '') : '').
		\    (self.ahead ? '>'.(self.ahead ># 1 ? self.ahead : '') : '')
		\  : !self.ahead && !self.behind
		\  ? '='
		\  : '').
		\ (!empty(self.operation)
		\  ? '|'.self.operation.(self.step ? ' '.self.step.'/'.self.total : '')
		\  : '')

	" So startup screen does not disappear. Eeerh.
	"if 2 <# bufnr('$')
		redrawstatus!
	"endif
endfunction

function! s:git_status_on_behind_ahead(data) abort dict
	try
		let [_, self.behind, self.ahead; _] = matchlist(a:data[0], '\v^(\d+)\t(\d+)$')
	catch
		let [self.behind, self.ahead] = [-1, -1]
		" Has no upstream.
		return
	endtry
	let self.behind = str2nr(self.behind)
	let self.ahead = str2nr(self.ahead)
	call call('s:git_statusline_update', [], self)
endfunction

function! s:git_status_on_head(data) abort dict
	let self.head = a:data[0]
	call call('s:git_statusline_update', [], self)
endfunction

function! s:git_status_on_status(data) abort dict
	let self.staged = 0 <=# match(a:data, '^\m[MARC]')
	let self.modified = 0 <=# match(a:data, '^\m.[MARC]')
	let self.untracked = 0 <=# match(a:data, '^\m\n??')
	call call('s:git_statusline_update', [], self)
endfunction

function! s:git_status_on_bootstrap(data) abort dict
	try
		let [self.dir, self.bare, self.inside, self.head, cdup; _] = a:data + ['']
	catch
		return
	endtry
	let self.bare = self.bare ==# 'true'
	let self.inside = self.inside ==# 'true'
	let self.wd = simplify(self.wd.cdup)

	let self.vcs = 'git'

	if !self.inside
		call s:git_run(self, 's:git_status_on_status', '--no-optional-locks', '-C', self.wd, 'status', '--porcelain')
	endif

	call s:git_run(self, 's:git_status_on_behind_ahead', '--no-optional-locks', '-C', self.wd, 'rev-list', '--count', '--left-right', '--count', '@{upstream}...@')

	" sequencer/todo
	if isdirectory(self.dir.'/rebase-merge')
		let self.operation = 'REBASE'
		let self.head = readfile(self.dir.'/rebase-merge/head-name')[0]
		try
			let self.step = +readfile(self.dir.'/rebase-merge/msgnum')[0]
			let self.total = +readfile(self.dir.'/rebase-merge/end')[0]
		catch
			" Editing message.
		endtry
	elseif isdirectory(self.dir.'/rebase-apply')
		if file_readable(self.dir.'/rebase-apply/rebasing')
			let self.head = readfile(self.dir.'/rebase-merge/head-name')[0]
			let self.operation = 'REBASE'
		elseif file_readable(self.dir.'/rebase-apply/applying')
			let self.operation = 'AM'
		else
			let self.operation = 'AM/REBASE'
		endif
		try
			let self.step = +readfile(self.dir.'/rebase-apply/next')[0]
			let self.total = +readfile(self.dir.'/rebase-apply/last')[0]
		catch
			" Editing message.
		endtry
	elseif file_readable(self.dir.'/MERGE_HEAD')
		let self.operation = 'MERGE'
	elseif file_readable(self.dir.'/CHERRY_PICK_HEAD')
		let self.operation = 'CHERRY-PICK'
	elseif file_readable(self.dir.'/REVERT_HEAD')
		let self.operation = 'REVERT'
	elseif file_readable(self.dir.'/BISECT_LOG')
		let self.operation = 'BISECT'
	else
		let self.operation = ''
	endif

	if self.head ==# 'HEAD'
		" Detached.
		call s:git_run(self, 's:git_status_on_head', '--no-optional-locks', '-C', self.wd, 'name-rev', '--name-only', self.head)
	endif

	let self.head = substitute(self.head, '^refs/heads/', '', '')

	call call('s:git_statusline_update', [], self)
endfunction

" git --no-optional-locks rev-list --walk-reflogs --count refs/stash
" /usr/share/git/git-prompt.sh
function! Git() abort
	let bufname = bufname()
	if 0 <=# match(bufname, '\v^[a-z]+://')
		return { 'status': '' }
	endif
	let dir = fnamemodify(bufname, ':p:h')
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
		call s:git_run(s:git[dir], 's:git_status_on_bootstrap', '--no-optional-locks', '-C', dir, 'rev-parse', '--abbrev-ref', '--absolute-git-dir', '--is-bare-repository', '--is-inside-git-dir', '@', '--show-cdup')
	endif
	return s:git[dir]
endfunction

augroup vimrc_git
	autocmd!

	let s:git = {}
	autocmd ShellCmdPost,FileChangedShellPost,TermLeave,VimResume * let s:git = {}

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
