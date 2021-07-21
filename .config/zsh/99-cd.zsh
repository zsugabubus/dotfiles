if [[ -o interactive ]]; then
	if [[ ! -o single_command && ! $0 = command ]]; then
		if [[ ! $PWD = ~ ]]; then
			if [[ $PWD = $XDG_RUNTIME_DIR/mem ]]; then
				cd ~m
			else
				l
			fi
		fi
	fi
fi
