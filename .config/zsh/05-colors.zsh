TRAPUSR2() {
	source $ZDOTDIR/theme.zsh
	exec >/dev/tty

	ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'

	export FZF_DEFAULT_OPTS='--tiebreak=end --layout=reverse --no-mouse --no-multi --hscroll-off=13'
	case $ZSH_THEME in
	light) FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=gutter:-1,pointer:214,hl+:226,hl:226,spinner:240" ;;
	dark)  FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=gutter:-1,pointer:214,hl+:226,hl:226,spinner:240" ;;
	esac

	case $TERM in
	linux)
		# See console_codes(4).
		printf '\e%G' # UTF-8.
		printf '\e]P%x%s' \
			0 000000 1 ec407a 2  8bc34a 3  ffa726 4  2196f3 5  9575cd 6  00bcd4 7  e6e7ef \
			8 264137 9 ec407a 10 9ccc65 11 ffb74d 12 42a5f5 13 b39ddb 14 26c6da 15 e6e7ef
		;;

	*)
		printf '\e]%d;#%s\a' 10 23252b 11 eeeeee 12 000000
		# Near equal lightness in Lab colorspace. Reference to red and orange.
		# http://colorizer.org/
		printf '\e]4;%d;#%s\a' \
			0 264137 1 fe2e1f 2  00a206 3  f59335 4  0091ff 5  a56cc9 6  00c6ff 7  44454f \
			8 264137 9 fe2e1f 10 00a206 11 f59335 12 0091ff 13 a56cc9 14 00c6ff 15 242526

		#0 264137 1 fe2e1f 2  11a71f 3  f59335 4  00aefb 5  a56cc9 6  00c5ff 7  44454f \
		#8 264137 9 fe2e1f 10 11a71f 11 f59335 12 00aefb 13 a56cc9 14 00c5ff 15 242526
		#a36ac7 03c7ef 11a6fb 1fc51f blue 4b5bfb 9: #9a5feb

		if [[ $ZSH_THEME == dark ]]; then
			printf '\e]%d;#%s\a' 10 cfcfcf 11 202230 12 f4f4f4
			printf '\e]4;%d;#%s\a' \
				2  2edd2e 6  5ef0f1 7  eaebef \
				10 2edd2e 14 5ef0f1 15 fefeff
		fi
		;;
	esac
}

TRAPUSR2
