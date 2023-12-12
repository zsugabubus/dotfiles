set -F @_ '\
	call cursor(#{history_size} + 1 + #{cursor_y}, 0)|\
	call winrestview({\
		"topline": #{history_size} + 1,\
		"col": virtcol2col(0, line("."), #{cursor_x}),\
	})|\
	let @/="#{pane_search_string}"|\
	let v:hlsearch = 1|\
	call feedkeys("#{@copy_feedkeys}", "t")\
'

capture-pane -e -E- -S- -b _copy

display-popup -B -E -T Copy -w '100%' -h '100%' \
	nvim \
		+'set nolist scrolloff=0 virtualedit=all laststatus=0 cmdheight=0 nonumber norelativenumber' \
		+'autocmd TextYankPost * call system("tmux load-buffer -", v:event.regcontents)|lua vim.schedule(vim.cmd.qall)' \
		+'call append(0, systemlist("tmux show-buffer -b _copy \\; delete-buffer -b _copy"))' \
		+'AnsiEsc' \
		+'set nomodified' \
		+'execute system("tmux display-message -pF \\#{@_}")|redraw'
# vim: ft=tmux
