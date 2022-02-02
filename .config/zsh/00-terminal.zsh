autoload -Uz add-zsh-hook

if [[ $TERM == linux ]]; then
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
