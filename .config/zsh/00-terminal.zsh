autoload -Uz add-zsh-hook

if [[ $TERM == linux ]]; then
	# See console_codes(4).
	printf '\e%G' # UTF-8.
	typeset -a PALETTE=(
		000000 ec407a 8bc34a ffa726 2196f3 9575cd 00bcd4 c4c4c4
		617d8a ec407a 9ccc65 ffb74d 42a5f5 b39ddb 26c6da ffffff
	)
	for i ({1..16}); printf '\e]P%x%s' $((i - 1)) ${PALETTE[$i]}
	setterm --blank 1 --powerdown 1 --powersave powerdown
fi

ttyctl -f

local function __terminal-preexec() {
	print -n "\e]0;${(q)1}\a"
}

local function __terminal-precmd() {
	# Set title and send bell. (Title sequence also ends with a bell.)
	print -nP "\e]0;%n@%m: %~%(1j/ [%j job%(2j.s.)]/)\a\a"
}

add-zsh-hook preexec __terminal-preexec
add-zsh-hook precmd __terminal-precmd
