if [[ -o login ]]; then
	print \
'(@-
//\\
V_/_
'
fi

# Display calendar once a day.
if [[ -o interactive ]]; then
	zmodload zsh/datetime
	zmodload -F zsh/stat b:zstat

	local zcal_state=$XDG_RUNTIME_DIR/.zcalstate

	if [[ $(zstat -F %j +mtime -- $zcal_state 2>/dev/null) != $(strftime %j) ]]; then
		touch -- $zcal_state
		{
			date +%F
			echo
			cal -mw --color=always
			(( $+aliases[ca] )) && ca
		} | less
	fi
fi
