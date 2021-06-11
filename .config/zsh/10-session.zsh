if [[ -o login ]]; then
	print \
'(@-
//\\
V_/_
'
fi

# Limit maximum number of processes.
ulimit -u 600

export LESS='-X -F -i -R -s -S'
export LESSHISTFILE=-

export EDITOR=nvim
export PAGER=less
export MANPAGER=$EDITOR' +"set ft=man mouse=a" -R'

export RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/ripgreprc

export ABDUCO_SOCKET_DIR=$XDG_RUNTIME_DIR
export DIFFPROG=$EDITOR' -d'

export FZF_DEFAULT_OPTS='--tiebreak=end --layout=reverse --no-mouse --no-multi --hscroll-off=13'

export GPG_TTY=$TTY
