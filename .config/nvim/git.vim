let g:git_symbols = "SMUT"
let g:git_symbols = "+*%$" " git-prompt
let g:git_max_tabs = 15
set switchbuf=useopen,usetab
nnoremap <silent><expr> gf (0 <=# match(expand('<cfile>'), '\v^\x{4,}$') ? ':pedit git://'.fnameescape(expand('<cfile>'))."\<CR>" : 0 <=# match(expand('<cfile>'), '^[ab]/') ? 'viWof/lgf' : 'gf')

function! s:git_ignore_stderr(chan_id, data, name) abort dict
endfunction

function! s:git_print_stderr(chan_id, data, name) abort dict
	call s:print_error(a:data)
endfunction

let s:git_jobs = {}

function! s:git_nvim_on_exit(chan_id, data, name) abort dict
	unlet s:git_jobs[a:chan_id]
endfunction

function! s:git_vim_on_exit(ch) abort
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
	call call(self.cb, [a:data], self.self)
endfunction

function! s:git_run(cb, ...) abort dict
	let cmd = ['git', '--no-optional-locks'] + a:000
	if 1 <=# &verbose
		echomsg 'git: Running ' string(cmd)
	end

	if has('nvim')
		let job_id = jobstart(cmd, {
			\  'pty': 0,
			\  'stdout_buffered': 1,
			\  'stderr_buffered': 1,
			\  'on_stdout': function('s:git_nvim_on_stdout'),
			\  'on_stderr': function(!empty(self) ? 's:git_ignore_stderr' : 's:git_print_stderr'),
			\  'on_exit': function('s:git_nvim_on_exit'),
			\  'self': self,
			\  'cb': a:cb
			\})
		if job_id <=# 0
			echoerr 'git: jobstart() failed'
			call interrupt()
		endif
		let s:git_jobs[job_id] = job_id
	else
		let job = job_start(cmd, {
			\  'in_io': 'null',
			\  'out_io': 'pipe',
			\  'err_io': 'null',
			\  'close_cb': function('s:git_vim_on_exit')
			\})
		let s:git_jobs[job_info(job).process] = [job, a:cb, self]
	endif
endfunction

function! s:git_cancel() abort
	if empty(s:git_jobs)
		echomsg 'git: No running jobs'
		return
	else
		echomsg printf('git: Cancelling %d jobs...', len(s:git_jobs))
	endif

	if has('nvim')
		for job_id in values(s:git_jobs)
			call jobstop(job_id)
		endfor
	else
		" TODO: Implement
	endif
endfunction

function! s:print_error(output) abort
	echohl Error
	echomsg join(a:output, "\n")
	echohl None
endfunction

function! s:git_do(...) abort
	if has('nvim')
		let cmd = ['git', '--no-optional-locks'] + a:000
	else
		let cmd = 'git --no-optional-locks'.join(map(copy(a:000), {_,x-> ' '.shellescape(x)}), '')
	endif
	if 1 <=# &verbose
		echomsg 'git: Running ' string(cmd)
	end
	let output = systemlist(cmd)
	if v:shell_error
		call s:print_error(output)
		call interrupt()
	endif
	return output
endfunction

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
		let b:git_job = job_start(['git'] + a:cmdline, {
			\  'in_io': 'null',
			\  'out_io': 'buffer',
			\  'out_buf': a:bufnr,
			\  'out_modifiable': 0
			\})
	endif
endfunction

function! s:git_edit_rev(edit, mod) abort
	let [_, rev, path; _] = matchlist(expand('%'), '\v^git://([^:]*)(.*)$')
	let output = s:git_do('rev-parse', rev.a:mod)
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

function! s:git_dir_complete(prefix, cmdline, pos) abort
	let wd = Git().wd
	return map(filter(globpath(wd, a:prefix.'*', 1, 1), 'isdirectory(v:val)'), 'v:val['.len(wd).':]."/"')
endfunction

for s:cd in ['cd', 'lcd', 'tcd']
	execute "command! -complete=customlist,<SID>git_dir_complete -nargs=? G".s:cd." execute '".s:cd." '.fnameescape(Git().wd.<q-args>)"
endfor

command! Gcancel call s:git_cancel()
command! -nargs=* Gshow execute 'edit git://'.(empty(<q-args>) ? expand('<cword>') : <q-args>)
command! -nargs=* -range=% Glog call s:git_log(<line1>, <line2>, <f-args>)
command! -nargs=* Gtree call s:git_tree(0, <f-args>)
command! -nargs=* Gtreediff call s:git_tree(1, <f-args>)
command! -nargs=* -range Gdiff call s:git_diff(<f-args>)
command! -nargs=* -range=% Gblame call s:git_blame(<line1>, <line2>, <f-args>)
for [s:git_cmd, s:cmd] in [['Gconflicts', 'laddexpr'], ['Gcconflicts', 'caddexpr']]
	execute "command! ".s:git_cmd." noautocmd g/^=======$/".s:cmd." expand('%').':'.line('.').':'.getline('.')|doautocmd QuickFixCmdPost ".s:cmd
endfor

function! s:git_log(firstlin, lastlin, ...) abort
	if a:firstlin ==# 1 && a:lastlin ==# line('$')
		enew
		nmap <silent><buffer><nowait> K k<Return>
		nmap <silent><buffer><nowait> J j<Return>
		call termopen(['git', 'log-vim'] + a:000)
	else
		vertical new
		call s:git_pager(['log', printf('-L%d,%d:%s', a:firstlin, a:lastlin, expand('#'))])
	endif
endfunction

function! s:git_tree(diff, ...) abort
	let list = []
	let common_diff_options = ['--root', '-r', '--find-renames']
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
	let output = call('s:git_do', cmd)

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

		let status_map = {
			\  'A': 'new',
			\  'C': 'copied',
			\  'D': 'gone',
			\  'M': 'modified',
			\  'R': 'renamed',
			\  'T': 'type changed',
			\  'U': 'unmerged'
			\}
		let too_much = g:git_max_tabs < len(output)

		for change in output
			let [_, src_mode, dst_mode, src_hash, dst_hash, status, score, src_path, dst_path; _] =
				\ matchlist(change, '\C\v^:(\d{6}) (\d{6}) ([0-9a-f]{40}) ([0-9a-f]{40}) ([A-Z])(\d*)\t([^\t]+)%(\t([^\t]+))?$')
			if src_hash =~# '\v^0{40}$'
				let src_hash = ''
			endif
			if dst_hash =~# '\v^0{40}$'
				let dst_hash = ''
			endif

			let filename = !empty(dst_path) ? dst_path : src_path
			let dst_bufname = (!empty(dst_hash) ? 'git://'.dst_hash.'/' : '').filename
			if a:diff && !too_much
				let dst_bufnr = bufnr(dst_bufname, 1)
				execute '$tab' dst_bufnr 'sbuffer'
				setlocal buflisted
				diffthis

				if !empty(src_hash)
					let src_bufname = 'git://'.src_hash.'/'.src_path
					let src_bufnr = bufnr(src_bufname, 1)
					execute 'vertical' src_bufnr 'sbuffer'
					diffthis
					wincmd H
				endif

				redraw
			else
				let dst_bufnr = 0
			endif

			call add(list, {
				\  'type': status,
				\  'bufnr': dst_bufnr,
				\  'module': filename,
				\  'filename': dst_bufname,
				\  'text':
				\    get(STATUS_MAP, status, '['.status.']').
				\    (!empty(dst_path) ? ' from '.src_path : '').
				\    (src_mode !=# dst_mode ? ' ('.src_mode.' -> '.dst_mode.')' : ''),
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

function! s:git_blame(firstlin, lastlin, ...) abort
	let args = a:000

	" Default range if not specified.
	if -1 ==# match(args, '^-L')
		let args = ['-L'.a:firstlin.','.a:lastlin] + args
	endif

	" Default search pattern. (Shorter than <C-R>/.)
	let magic_l = match(args, '^-L/')
	if 0 <=# magic_l
		let args = copy(args)
		let args[magic_l] = '-L/'.escape(getreg('/'), '\/') .'/'
	endif

	let file = expand('%')
	let args = ['blame'] + args + (!empty(file) ? ['--', file] : file)
	call call('s:git_run', ['s:git_blame_stdout'] + args, {})
endfunction

function! s:git_blame_jump(flags)
	call search('\v^([^ ]* ).*\n\zs\1@!', 'W'.a:flags)
	let @/ = '\V'.escape(matchstr(getline(line('.')), '\m^[^ ]*'), '\')

	" Setting it to 1 does nothing hence this workaround.
	if !v:hlsearch
		call feedkeys(":set hlsearch|echo\<CR>", 'n')
	endif
endfunction

function! s:git_blame_width(n) abort
	let w:git_blame_winwidth = a:n
	execute 'vertical' 'resize' w:git_blame_winwidth
endfunction

function! s:git_blame_stdout(data) abort dict range
	if len(a:data) <=# 1
		return
	endif

	let cur_lnum = line('.')
	setlocal scrollbind

	let buf = bufadd('')
	call setbufvar(buf, '&bufhidden', 'wipe')
	call setbufvar(buf, '&buftype', 'nofile')
	call setbufvar(buf, '&swapfile', 0)
	call setbufvar(buf, '&undolevels', -1)

	execute 'vertical' 'leftabove' 'sbuffer' buf
	setlocal norelativenumber nonumber
	nmap <nowait><silent><buffer> <CR> gf
	nmap <nowait><silent><buffer> [ :call <SID>git_blame_jump('b')<CR>
	nmap <nowait><silent><buffer> ] :call <SID>git_blame_jump('')<CR>
	nmap <nowait><silent><buffer> c :call <SID>git_blame_width(9)<CR>
	nmap <nowait><silent><buffer> a :call <SID>git_blame_width(29)<CR>
	nmap <nowait><silent><buffer> d :call <SID>git_blame_width(54)<CR>

	let last_lnum = 1
	for line in a:data
		if !empty(line)
			let lnum = +matchstr(line, '\v \zs\d+\ze\)', 42) " Magic number
			if last_lnum <# lnum
				call appendbufline(buf, last_lnum, repeat([''], lnum - last_lnum))
			endif
			call setbufline(buf, lnum, line)
			let last_lnum = lnum + 1
		endif
	endfor

	call feedkeys('d')
	call cursor(cur_lnum, 1)
	redraw " Otherwise scrollbind gets fucked up.
	setlocal nomodifiable scrollbind
	setlocal ft=git-blame
endfunction

function! g:Git_blame_do_winresize() abort
	let winnr = winnr()
	for i in range(1, winnr('$'))
		let winwidth = getwinvar(i, 'git_blame_winwidth')
		if winwidth
			execute i.'windo' 'vertical' 'resize' winwidth
		endif
	endfor
	execute winnr.'windo :'
endfunction

function! s:git_setup_diff_ft()
	map <nowait><silent><buffer> [ :call search('\m^@@ ', 'bW')<CR>
	map <nowait><silent><buffer> ] :call search('\m^@@ ', 'W')<CR>
	map <nowait><silent><buffer> { :call search('\m^diff ', 'bW')<CR>
	map <nowait><silent><buffer> } :call search('\m^diff ', 'W')<CR>
endfunction

function! s:git_statusline_update() abort dict
	let self.status =
		\ (self.bare ? 'BARE:' : '').
		\ self.head.
		\ (g:git_symbols[0][!self.staged]).
		\ (g:git_symbols[1][!self.modified]).
		\ (g:git_symbols[2][!self.untracked]).
		\ (0 <# self.stashed
		\  ? g:git_symbols[3].(1 <# self.stashed ? self.stashed : '') : '').
		\ (0 <# self.ahead || 0 <# self.behind
		\  ? (self.behind ? '<'.(1 <# self.behind ? self.behind : '') : '').
		\    (self.ahead ? '>'.(1 <# self.ahead ? self.ahead : '') : '')
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
	let self.behind = +self.behind
	let self.ahead = +self.ahead
	call call('s:git_statusline_update', [], self)
endfunction

function! s:git_status_on_stashed(data) abort dict
	let self.stashed = +a:data[0]
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

	if !self.staged && !self.modified
		call call('s:git_run', [
			\  's:git_status_on_stashed',
			\  '-C', self.wd,
			\  'rev-list',
			\  '--walk-reflogs',
			\  '--count',
			\  'refs/stash',
			\], self)
	else
		let self.stashed = -1
	endif

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
		call call('s:git_run', [
			\  's:git_status_on_status',
			\  '-C', self.wd,
			\  'status',
			\  '--porcelain'
			\], self)
	endif

	call call('s:git_run', [
		\  's:git_status_on_behind_ahead',
		\  '-C', self.wd,
		\  'rev-list',
		\  '--count',
		\  '--left-right',
		\  '--count',
		\  '@{upstream}...@'
		\], self)

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
		call call('s:git_run', [
		\  's:git_status_on_head',
		\  '-C', self.wd,
		\  'name-rev',
		\  '--name-only',
		\  self.head
		\], self)
	endif

	let self.head = substitute(self.head, '^refs/heads/', '', '')

	call call('s:git_statusline_update', [], self)
endfunction

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
			\  'stashed': 0,
			\  'untracked': 0,
			\  'behind': 0,
			\  'ahead': 0,
			\  'operation': '',
			\  'step': 0,
			\  'total': 0,
			\  'status': ''
			\}
		call call('s:git_run', [
			\  's:git_status_on_bootstrap',
			\  '-C', dir,
			\  'rev-parse',
			\  '--abbrev-ref',
			\  '--absolute-git-dir',
			\  '--is-bare-repository',
			\  '--is-inside-git-dir',
			\  '@',
			\  '--show-cdup'
			\], s:git[dir])
	endif
	return s:git[dir]
endfunction

augroup vimrc_git
	autocmd!

	" Defer window resizing since nvim crashes if it is done as part of the
	" autocmd handler.
	autocmd VimResized * if mode(1) ==# 'n'|call feedkeys(":call g:Git_blame_do_winresize()|echo\<CR>", 'ni')|endif

	let s:git = {}
	autocmd ShellCmdPost,FileChangedShellPost,TermLeave,VimResume * let s:git = {}

	autocmd BufReadCmd git://* ++nested
		\ call s:git_pager([
		\   'show',
		\   '--compact-summary',
		\   '--patch',
		\   '--stat-width='.winwidth(0),
		\   '--format=format:commit %H%nparent %P%ntree %T%nref: %D%nAuthor: %aN <%aE>%nDate:   %aD%nCommit: %cN <%cE>%n%n    %s%n%-b%n',
		\   matchstr(expand("<amatch>"), '\v://\zs[^:/]*%(:.*)?')
		\ ])

	" Highlight conflict markers.
	autocmd Colorscheme * match ErrorMsg '^\(<\|=\|>\)\{7\}\([^=].\+\)\?$'

	autocmd FileType diff call s:git_setup_diff_ft()
augroup END
