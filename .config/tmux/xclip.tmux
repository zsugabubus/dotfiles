# In a perfect world buffer name would be 'xclip_#{@xclip_selection}' but I do
# not want to fuck more hours figuring out how can I do so. Running
# paste-buffer with run-shell swallows error messages (e.g. no display-message about
# empty clipboard).
# FUCK YOUR DSL!
run-shell 'xclip -silent -o -selection #{@xclip_selection} -r | tmux load-buffer -b xclip -'
if -F '#{==:#{pane_current_command},weechat}' { \
	choose-buffer { paste-buffer -b '%%' -d -p } \
} { \
	paste-buffer -b xclip -d -p \
}
# vim:ft=tmux
