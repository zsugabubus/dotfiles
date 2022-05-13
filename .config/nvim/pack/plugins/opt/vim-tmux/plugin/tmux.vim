function! s:wincmd_magic(win_cmd, tmux_cmd)
	let cur = winnr()
	execute 'wincmd' a:win_cmd
	" Something happened.
	if cur !=# winnr()
		return
	endif

	if empty($TMUX)
		return
	endif
	let saved_pane_id = systemlist([
	\  'tmux',
	\  'display-message', '-p', '-F', '#{pane_id}', ';',
	\  'select-pane', '-t', '{'.a:tmux_cmd[0].'}',
	\])
	if !empty(a:tmux_cmd[1])
		call systemlist([
		\  'tmux',
		\  'if', '-F', '#{==:#{pane_id},'.saved_pane_id[0].'}', 'select-window -t "{'.a:tmux_cmd[1].'}"',
		\])
	endif
endfunction

for [s:win_cmd, s:tmux_cmd] in items({
\  'h': ['left-of', 'previous'],
\  'l': ['right-of', 'next'],
\  'j': ['down-of', ''],
\  'k': ['up-of', ''],
\  'w': ['last', 'last']
\})
	for s:lhs in [s:win_cmd, '<C-'.s:win_cmd.'>']
		execute 'nnoremap <silent> <C-w>'.s:lhs.' :call <SID>wincmd_magic('.string(s:win_cmd).','.string(s:tmux_cmd).')<CR>'
	endfor
endfor
