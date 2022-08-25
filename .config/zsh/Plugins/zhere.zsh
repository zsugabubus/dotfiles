typeset -g _ZSH_HERE_FILE=$XDG_RUNTIME_DIR/.zhere

function here() {
	print >$_ZSH_HERE_FILE -- $PWD
	printf '~[here]=%q\n' ~[here]
}

add-zsh-hook -Uz zsh_directory_name here_directory_name
