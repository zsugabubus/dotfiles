autoload -Uz zsh/terminfo

local function autoload_zle() {
	autoload -Uz "$@" &&
	zle -N "$@"
}

source /usr/share/fzf/key-bindings.zsh

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

bindkey -v # Vim

# Delay after mode change.
KEYTIMEOUT=1

local function bindkey-M() {
	local keymap=$1
	shift 1
	while (( $# )); do
		bindkey -M viins "$1" "$2"
		shift 2
	done
}

autoload_zle dot-magic
bindkey -M viins . dot-magic

autoload_zle fuzzy-open
bindkey-M viins \
	'^O' fuzzy-open \
	'^F' fuzzy-open \

autoload_zle complete-commit
bindkey -M viins '^Xc' complete-commit

autoload_zle edit-command-line
bindkey -M viins '^V' edit-command-line
bindkey -M vicmd '^V' edit-command-line

autoload_zle edit-command-words
bindkey -M viins '^[v' edit-command-words
bindkey -M vicmd '^Xv' edit-command-words

autoload_zle ctrlz-magic
bindkey -M viins '^Z' ctrlz-magic
bindkey -M vicmd '^Z' ctrlz-magic

bindkey-M vicmd \
	'^A' beginning-of-line \
	'^E' end-of-line \

bindkey-M viins \
	'^[^M' autosuggest-execute \
	'^[f' forward-word \
	'^[b' backward-word \
	'^A' beginning-of-line \
	'^E' end-of-line \
	'^W' backward-kill-word \
	'^P' up-history \
	'^N' down-history \
	'^H' backward-delete-char \
	"^[h" backward-char \
	"^[l" forward-char

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
	# compstate[insert]=''
}

local function expand-or-complete-or-list-files() {
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
zle -N expand-or-complete-or-list-files
bindkey -M viins '^I' expand-or-complete-or-list-files

zle -C all-matches complete-word _my_generic
zstyle ':completion:all-matches:*' old-matches only
zstyle ':completion:all-matches::::' completer _all_matches
function _my_generic() {
	_all_matches "$@"
}
bindkey -M viins '^X^I' all-matches

# <C-?>
bindkey -M viins '^_' run-help
bindkey -M vicmd '^_' run-help

function accept-line() {
	# r-magic
	if [[ -v _zle_accept_line_rerun && -z $BUFFER ]]; then
		BUFFER=r
	elif [[ $BUFFER = r ]]; then
		_zle_accept_line_rerun=
	else
		unset _zle_accept_line_rerun
	fi
	zle .accept-line
}
zle -N accept-line

local function zle-run-chpwd() {
	# Start new line after cursor.
	echo
	cd .
	zle .reset-prompt
}
zle -N zle-run-chpwd
bindkey -M viins '^L' zle-run-chpwd

# Menuselect
bindkey -M menuselect \
	'=' accept-and-infer-next-history \
	'a' accept-and-hold \
	'^M' .accept-line
bindkey -M menuselect -s ' ' a

# zle -C complete-menu menu-select _generic
# complete_menu() {
	# setopt localoptions alwayslastprompt
#		zle menu-select
# }
# zle -N complete_menu
bindkey -M viins '^X^M' menu-select
bindkey-M viins \
	'^Xl' list-expand \
	'^X*' expand-word \
	'^X^X' menu-select

bindkey -s -M menuselect j $terminfo[kcud1]
bindkey -s -M menuselect k $terminfo[kcuu1]
bindkey -s -M menuselect l $terminfo[kcuf1]
bindkey -s -M menuselect h $terminfo[kcub1]

autoload -Uz run-help
unalias run-help
autoload -Uz run-help-{git,ip,openssl,p4,sudo,svk,svn}

autoload -Uz paste-magic
zle -N bracketed-paste paste-magic

ZSH_AUTOSUGGEST_MANUAL_REBIND=true
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

autoload -Uz zmail && zmail

set -o ignore_eof
local function zle-exit() {
	zle .reset-prompt
	if [[ -n $zsh_scheduled_events ]]; then
		print "zsh: you have scheduled events"
	elif [[ -o login ]]; then
		read -esrq "?zsh: surely exit? " && exit
	else
		exit
	fi

	zle redisplay
	return
}
zle -N zle-exit
bindkey -M viins '^D' zle-exit

unfunction autoload_zle
