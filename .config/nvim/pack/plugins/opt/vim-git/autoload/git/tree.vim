function! git#tree#open(diff, ...) abort
	let list = []
	let common_diff_options = ['--root', '-r', '--find-renames']
	let W = '\v^[W/]$'
	let I = '\v^%(I|:|:0|0)$'
	if !a:0
		" Compare working tree and index against head.
		let cmd = ['status', '--porcelain']
	elseif a:1 =~# W && get(a:000, 2, 'I') =~# I " W [I]
		let cmd = ['diff-files'] + common_diff_options
	elseif a:1 =~# W && a:0 == 2 " W <tree>
		let cmd = ['diff-index'] + common_diff_options + [a:2]
	elseif a:1 =~# I " I [<tree>=HEAD]
		let cmd = ['diff-index', '--cached'] + common_diff_options + [get(a:000, 2, '@')]
	elseif a:0 == 2 && a:2 =~# I " <tree> I
		let cmd = ['diff-index', '--cached', '-R'] + common_diff_options + [a:1]
	elseif a:0 == 2 && a:2 =~# W " <tree> W
		let cmd = ['diff-index', '-R'] + common_diff_options + [a:1]
	else " <tree-1> [<tree-2>=<tree-1> parents]
		let cmd = ['diff-tree'] + common_diff_options + a:000
	endif
	let output = call('git#cmd#output', cmd)

	" call add(list, {
	" 	\  'text': 'status of '.join(a:000, ' '),
	" 	\})

	if cmd[0] ==# 'status'
		let wd = Git().wd
		for change in output
			let [_, status, path; _] = matchlist(change, '\v^(..) (.*)$')
			call add(list, {
				\  'filename': wd.path,
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
				\    get(status_map, status, '['.status.']').
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
