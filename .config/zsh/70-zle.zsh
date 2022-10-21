autoload -Uz zsh/terminfo

function autoload_zle() {
	autoload -Uz "$@" &&
	zle -N "$@"
}

setopt auto_cd
setopt auto_continue
setopt auto_pushd
setopt auto_resume
setopt cbases
setopt cdable_vars
setopt check_jobs
setopt check_running_jobs
setopt csh_null_glob
setopt interactive_comments
setopt ksh_option_print
setopt long_list_jobs
setopt magic_equal_subst # cmd opt=~ -> cmd opt=/home/...
setopt multios
setopt noflow_control
setopt notify
setopt pushd_ignore_dups
setopt pushd_silent
setopt rm_star_wait

WORDCHARS=${WORDCHARS//[\/.-_]}

# Delay after mode change.
KEYTIMEOUT=1

bindkey -v # Vim

bindkey -M viins \
	'^[f' forward-word \
	'^[b' backward-word \
	'^A' beginning-of-line \
	'^E' end-of-line \
	'^W' backward-kill-word \
	'^P' up-history \
	'^N' down-history \
	'^H' backward-delete-char \
	'^K' kill-line \
	"^[h" backward-char \
	"^[l" forward-char \

bindkey -M viins \
	'^[^M' autosuggest-execute \
	'^X^M' menu-select \
	'^X^X' menu-select \
	'^X*' expand-word \
	'^Xl' menu-complete \

autoload_zle dot-magic
bindkey -M viins . dot-magic

autoload_zle slash-magic
bindkey -M viins / slash-magic

autoload_zle fuzzy-open
bindkey -M viins '^F' fuzzy-open

autoload_zle complete-commit
bindkey -M viins '^Xc' complete-commit

autoload_zle edit-command-line
bindkey -M viins '^V' edit-command-line
bindkey -M vicmd '^V' edit-command-line

autoload_zle edit-command-words
bindkey -M viins \
	'^[v' edit-command-words \
	'^Xv' edit-command-words \

autoload_zle ctrlz-magic
bindkey -M viins '^Z' ctrlz-magic
bindkey -M vicmd '^Z' ctrlz-magic

zle -C complete-file complete-word _generic
zstyle ':completion:complete-file::::' completer _files
bindkey -M viins '^Xf' complete-file

# Stolen from functions/Zle/predict-on.
function i-do-not-wish-to-see() {
	# Do not care about how many matches we have. Lines are the only thing that count.
	compstate[list_max]=100000
	if (( compstate[list_lines]+BUFFERLINES > LINES )); then
		compstate[list]=''
	else
		compstate[list]='list force'
	fi
}

function __zle-expand-or-complete-or-list-files() {
	if [[ $#BUFFER == 0 ]]; then
		LBUFFER=': '
		zle list-choices
		zle backward-kill-word
	else
		zle expand-or-complete
		comppostfuncs+=( i-do-not-wish-to-see )
		zle list-choices
	fi
}
zle -N {,__zle-}expand-or-complete-or-list-files
bindkey -M viins '^I' expand-or-complete-or-list-files

autoload -Uz run-help
unalias run-help
autoload -Uz run-help-{git,ip,openssl,p4,sudo}
# <C-?>
bindkey -M viins '^_' run-help
bindkey -M vicmd '^_' run-help

function __zle-fuzzy-reverse-history-search() {
	LBUFFER=$(
		fc -rln 0 999999 |
		fizzy -s -q "$BUFFER"
	)
	RBUFFER=
	zle .redisplay
}
zle -N {,__zle-}fuzzy-reverse-history-search
bindkey -M viins '^R' fuzzy-reverse-history-search

function __zle-accept-line() {
	# r-magic
	if (( $+_zle_accept_line_rerun && ! $#BUFFER )); then
		BUFFER=r
	elif [[ $BUFFER = r ]]; then
		_zle_accept_line_rerun=
	else
		unset _zle_accept_line_rerun
	fi
	zle .accept-line
}
zle -N {,__zle-}accept-line

function __zle-run-chpwd() {
	echo # Start new line after cursor.
	cd .
	zle .reset-prompt
}
zle -N {,__zle-}run-chpwd
bindkey -M viins '^L' run-chpwd

bindkey -M menuselect \
	'=' accept-and-infer-next-history \
	'a' accept-and-hold \
	'^M' .accept-line \

bindkey -M menuselect -s \
	' ' a \
	h $terminfo[kcub1] \
	j $terminfo[kcud1] \
	k $terminfo[kcuu1] \
	l $terminfo[kcuf1] \

autoload -Uz paste-magic
zle -N bracketed-paste paste-magic

autoload -Uz zmail && zmail

set -o ignore_eof
function __zle-exit() {
	zle .reset-prompt
	if [[ -n $zsh_scheduled_events ]]; then
		print "zsh: you have scheduled events"
	elif [[ -o login ]]; then
		read -esrq "?zsh: surely exit? " && exit
	else
		exit
	fi

	zle .redisplay
}
zle -N {,__zle-}exit
bindkey -M viins '^D' exit

unfunction autoload_zle

ZSH_AUTOSUGGEST_MANUAL_REBIND=true
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
