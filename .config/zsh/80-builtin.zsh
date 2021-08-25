function preexec() {
	print -n "\e]0;${(q)1}\a"
}

function precmd() {
	# Set title and send bell. (Title sequence also ends with a bell.)
	print -nP "\e]0;%n@%m: %~%(1j/ [%j job%(2j.s.)]/)\a\a"
}

function chpwd() {
	dirs -v
	lt
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

TIMEFMT='%J  %U user %S system %P cpu %*E total %MkB max %R faults'
REPORTTIME=1
