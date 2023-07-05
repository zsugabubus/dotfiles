set -F @_ '
	call cursor(#{history_size} + 1 + #{cursor_y}, 0)|
	call cursor(0, virtcol2col(0, line("."), #{cursor_x} + 1))|
	let @/="#{pane_search_string}"|
	let v:hlsearch = 1
'

display-popup -B -E -T Copy -w '100%' -h '100%' \
	sh -c '
	tmux capture-pane -ep -S- | \
	nvim \
		"+set nolist virtualedit=all scrolloff=0 laststatus=0 cmdheight=0 nonumber norelativenumber" \
		+"autocmd TextYankPost * call system(\"tmux load-buffer -\", v:event.regcontents)|lua vim.schedule(vim.cmd.qall)" \
		+AnsiEsc \
		"+$(tmux display-message -pF "#{@_}")" \
		+redraw \
		"+call feedkeys(\"$(tmux display-message -p "#{@copy_feedkeys}")\", \"t\")" \
	;:
'
