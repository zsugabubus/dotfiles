display-popup -b heavy -E -T Copy -w '100%' -h '100%' \
	sh -c '
	tmux capture-pane -ep -S "$(tmux display-message -p "#{?@copy_visible,0,-}")" |
	nvim \
		"+set nolist virtualedit=all scrolloff=0 laststatus=0 cmdheight=0 $(tmux display-message -p "#{?@copy_visible,nonumber norelativenumber,}")" \
		+AnsiEsc \
		+"silent g/  /s/\v {2,}( [^ ]+)* *$//e|nohlsearch" \
		+"autocmd TextYankPost * call system(\"tmux load-buffer -\", v:event.regcontents)|lua vim.schedule(vim.cmd.qall)" \
		"+call feedkeys($(tmux display-message -p "#{?@copy_visible,(#{cursor_y}+1).\"G\".(#{cursor_x}+1).\"|\",\"G$\"}.\"#{@copy_feedkeys}\""), \"t\")" \
	;:
'
