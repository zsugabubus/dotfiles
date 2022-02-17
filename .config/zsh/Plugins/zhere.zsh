alias -g There='~[here]'
alias -g Tmux='~[tmux-pane]'

typeset -g _ZSH_HERE_FILE=$XDG_RUNTIME_DIR/.zhere
function here() {
	print >$_ZSH_HERE_FILE -- $PWD
	printf 'There=%q\n' There
}

add-zsh-hook -Uz zsh_directory_name tmux_directory_name
add-zsh-hook -Uz zsh_directory_name here_directory_name
