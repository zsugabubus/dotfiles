TRAPUSR2() {
	source $ZDOTDIR/theme.zsh
	exec >/dev/tty

	ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'

	case $TERM in
	linux)
		# See console_codes(4).
		printf '\e%G' # UTF-8.
		printf '\e]P%x%s' \
			0 000000 1 ec407a 2  8bc34a 3  ffa726 4  2196f3 5  9575cd 6  00bcd4 7  e6e7ef \
			8 264137 9 ec407a 10 9ccc65 11 ffb74d 12 42a5f5 13 b39ddb 14 26c6da 15 e6e7ef
		;;
	esac
}

TRAPUSR2
