if [[ -o login ]]; then
	print \
'(@-
//\\
V_/_
'
fi

if [[ ! -o login ]] || [[ $TTY != /dev/tty1 ]]; then
	# limit maximum number of processes
	ulimit -u 600

	export LESS='-X -F -i -R -s -S'
	export LESSHISTFILE=-
	# export TASKRC=~/.config/taskwarrior/taskrc

	export EDITOR=nvim
	export PAGER=less
	export MANPAGER=$EDITOR' +"set ft=man mouse=a" -R'

	# Disable persistent REPL history.
	export NODE_REPL_HISTORY=

	export RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/ripgreprc

	export ABDUCO_SOCKET_DIR=$XDG_RUNTIME_DIR
	export DIFFPROG=$EDITOR' -d'

	# export MANPATH="$MANPATH:$(find -H ~/.rustup/toolchains -mindepth 3 -maxdepth 4 -name man -printf :%p 2>/dev/null)"
fi

export FZF_DEFAULT_OPTS='--tiebreak=end --layout=reverse --no-mouse --no-multi --hscroll-off=13'
export GPG_TTY=$TTY

# Heck. Where should it go?
zmodload zsh/sched
