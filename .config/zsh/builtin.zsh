function preexec() {
	print -n "\e]0;${(q)1}\a"
}

function precmd() {
	print -nP "\e]0;%n@%m: %~%(1j/ [%j job%(2j.s.)]/)\a"
}

function chpwd() {
	lt -I '*.aria2' -I '*.torrent'
}

function command_not_found_handler() {
	print -u2 -r "zsh: command not found: ${(q)1}.  This incident will be reported."
	return 127
}

function run-chpwd() {
	# Start new line after cursor.
	echo
	chpwd
	zle reset-prompt
}
zle -N run-chpwd

watch=all # watch all logins
logcheck=30 # every 30 seconds
WATCHFMT="%n from %M has %a tty%l at %T %W"

TIMEFMT='%J  %U user %S system %P cpu %*E total %MkB max %R faults'
