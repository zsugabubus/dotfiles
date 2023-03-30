let s:GIT_EMPTY = { 'status': '' }

function! git#status#update(...) abort
	let dir = get(a:000, 0, getcwd())
	if match(dir, '\v^[a-z]+://') >= 0 || '/tmp' ==# dir
		return s:GIT_EMPTY
	endif
	if !has_key(g:git, dir)
		let g:git[dir] = {
			\  'vcs': '',
			\  'dir': '',
			\  'wd': dir.'/',
			\  'cdup': '',
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
			\  'status': '',
			\  'head': 'undefined',
			\  'detached': 0
			\}
		" NOTE: "@" must be the last because git stops on first failure.
		call call('git#cmd#run', [
			\  'git#status#on_bootstrap',
			\  '-C', dir,
			\  'rev-parse',
			\  '--path-format=relative',
			\  '--abbrev-ref',
			\  '--absolute-git-dir',
			\  '--is-bare-repository',
			\  '--is-inside-git-dir',
			\  '--show-cdup',
			\  '--git-dir',
			\  'HEAD'
			\], g:git[dir])
	endif
	return g:git[dir]
endfunction

function! git#status#on_behind_ahead(data) abort dict
	try
		let [_, self.behind, self.ahead; _] = matchlist(a:data[0], '\v^(\d+)\t(\d+)$')
	catch
		let [self.behind, self.ahead] = [-1, -1]
		" Has no upstream.
		return
	endtry
	let self.behind = +self.behind
	let self.ahead = +self.ahead
	call call('git#status#statusline_update', [], self)
endfunction

function! git#status#on_stashed(data) abort dict
	let self.stashed = +a:data[0]
	call call('git#status#statusline_update', [], self)
endfunction

function! git#status#resolve_detached_head() abort dict
	if self.head[:8] == 'detached '
		let self.detached = 1
		let self.head = self.head[9:]
	endif

	call call('git#cmd#run', [
	\  'git#status#on_detached_head',
	\  '-C', self.wd,
	\  'name-rev',
	\  '--name-only',
	\  self.head
	\], self)
endfunction

function! git#status#on_symbolic_head(data) abort dict
	" Not symbolic.
	if a:data[0] == ''
		call call('git#status#resolve_detached_head', [], self)
		return
	endif

	let self.head = a:data[0]
	call call('git#status#statusline_update', [], self)
endfunction

function! git#status#on_detached_head(data) abort dict
	" git name-rev failed. Show hash.
	if a:data[0] == 'undefined'
		call call('git#cmd#run', [
		\  'git#status#on_detached_head',
		\  '-C', self.wd,
		\  'rev-parse',
		\  '--short',
		\  'HEAD'
		\], self)
		return
	end

	let self.head = a:data[0]
	call call('git#status#statusline_update', [], self)
endfunction

function! git#status#on_status(data) abort dict
	let self.staged = match(a:data, '^\m[MARC]') >= 0
	let self.modified = match(a:data, '^\m.[MARC]') >= 0
	let self.untracked = match(a:data, '^\m\n??') >= 0

	if !self.staged && !self.modified
		call call('git#cmd#run', [
			\  'git#status#on_stashed',
			\  '-C', self.wd,
			\  'rev-list',
			\  '--walk-reflogs',
			\  '--count',
			\  'refs/stash',
			\], self)
	else
		let self.stashed = -1
	endif

	call call('git#status#statusline_update', [], self)
endfunction

function! git#status#on_bootstrap(data) abort dict
	try
		let [
		\  self.dir, self.bare, self.inside, self.cdup, cdup2, self.head;
		\_] = a:data + ['']
	catch
		return
	endtry
	let self.bare = self.bare ==# 'true'
	let self.inside = self.inside ==# 'true'
	if self.inside
		let [self.cdup, self.head] = [simplify(self.cdup.'/..').'/', cdup2]
	endif
	let self.wd = simplify(self.wd.self.cdup)

	let self.vcs = 'git'

	if !self.inside
		call call('git#cmd#run', [
			\  'git#status#on_status',
			\  '-C', self.wd,
			\  'status',
			\  '--porcelain'
			\], self)
	endif

	" HEAD -> not a real branch.
	if self.head ==# 'HEAD'
		let [self.behind, self.ahead] = [-1, -1]
	else
		call call('git#cmd#run', [
			\  'git#status#on_behind_ahead',
			\  '-C', self.wd,
			\  'rev-list',
			\  '--count',
			\  '--left-right',
			\  '--count',
			\  '@{upstream}...@'
			\], self)
	endif

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

	" HEAD is symbolic but could not resolve to a revision,
	if self.head ==# 'HEAD'
		call call('git#cmd#run', [
		\  'git#status#on_symbolic_head',
		\  '-C', self.wd,
		\  'symbolic-ref',
		\  '--short',
		\  self.head
		\], self)
	" */head-name.
	elseif self.head =~# '\v^detached HEAD$|^refs/'
		call call('git#status#resolve_detached_head', [], self)
	endif

	call call('git#status#statusline_update', [], self)
endfunction

function! git#status#statusline_update() abort dict
	let self.status =
		\ (self.bare ? 'BARE:' : '').
		\ (self.detached ? 'detached ' : '').self.head.
		\ (g:git_symbols[0][!self.staged]).
		\ (g:git_symbols[1][!self.modified]).
		\ (g:git_symbols[2][!self.untracked]).
		\ (self.stashed > 0
		\  ? g:git_symbols[3].(self.stashed > 1 ? self.stashed : '') : '').
		\ (self.ahead == 0 && self.behind == 0
		\  ? '='
		\  : (self.behind > 0 ? '<'.(self.behind > 1 ? self.behind : '') : '').
		\    (self.ahead > 0 ? '>'.(self.ahead > 1 ? self.ahead : '') : '')).
		\ (!empty(self.operation)
		\  ? '|'.self.operation.(self.step ? ' '.self.step.'/'.self.total : '')
		\  : '')

	" So startup screen does not disappear. Eeerh.
	"if 2 <# bufnr('$')
		redrawstatus!
	"endif
endfunction
