DIRSTACKSIZE=10

# Allow comments
setopt interactive_comments
setopt ksh_option_print

# Glob
setopt csh_null_glob

# Directory
setopt auto_cd # $ dir -> $ cd dir
setopt auto_pushd
setopt pushd_ignore_dups
setopt cdable_vars # auto ~ prefix
setopt pushd_silent
setopt magic_equal_subst # cmd opt=~ -> cmd opt=/home/...

# Jobs
setopt auto_continue
setopt auto_resume
setopt long_list_jobs
setopt notify
setopt check_jobs
setopt check_running_jobs

# I/O
setopt multios # >one >two

setopt cbases # 0x instead of 16#

autoload -Uz zsh/terminfo
WORDCHARS=${WORDCHARS//[\/.-_]}
bindkey -v
# Delay after mode change.
KEYTIMEOUT=1

function autoload_zle() {
	autoload -Uz $@ &&
	zle -N $@
}

autoload_zle dot-magic
bindkey -M viins . dot-magic

autoload_zle fuzzy-open
bindkey -M viins '^O' fuzzy-open
bindkey -M viins '^F' fuzzy-open
# bindkey -M viins '^T' fuzzy-common-dirs

autoload_zle edit-command-line
bindkey '^V' edit-command-line
bindkey -M vicmd '^V' edit-command-line

autoload_zle edit-command-words
bindkey '^X^V' edit-command-words
# bindkey '^[v' edit-command-words
bindkey -M vicmd '^X^V' edit-command-words

autoload_zle ctrlz-magic
bindkey -M viins '^Z' ctrlz-magic

# bindkey -M viins $terminfo[kcuu1] history-substring-search-up
# bindkey -M viins $terminfo[kcud1] history-substring-search-down
# bindkey -M viins '^P' history-substring-search-up
# bindkey -M viins '^N' history-substring-search-down

bindkey -M viins '^[^M' autosuggest-execute
bindkey -M viins '^[f' forward-word
bindkey -M viins '^[b' backward-word
bindkey -M vicmd '^A' beginning-of-line
bindkey -M vicmd '^E' end-of-line
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^E' end-of-line
bindkey -M viins '^w' backward-kill-word
bindkey -M viins '^P' up-history
bindkey -M viins '^N' down-history
bindkey -M viins '^h' backward-delete-char
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M viins "^[h" backward-char
bindkey -M viins "^[l" forward-char

zle -C complete-file complete-word _generic
zstyle ':completion:complete-file::::' completer _files
bindkey -M viins '^Xf' complete-file
bindkey -M viins '^X/' complete-file
bindkey -M viins '^X.' complete-file

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

function self-insert() {
	zle .self-insert

	# Magic list choices for things that **looks like**:
	# - arguments,
	# - environment variables and variable qualifiers,
	# - paths (+cd ..., ./...),
	# - globs.
	if [[ $LBUFFER =~ '(\s--?\w|\$\w\w|:|\*\S*\()\S*$|^cd\s+|^\.' && ! $LBUFFER = git* ]]; then
		comppostfuncs=( i-do-not-wish-to-see )
		zle list-choices
	fi
}
zle -N self-insert

function expand-or-complete-or-list-files() {
	if [[ $#BUFFER == 0 ]]; then
		LBUFFER='ls '
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

autoload_zle copy-earlier-word
bindkey -M viins '^[p' copy-earlier-word

bindkey -M viins '^[.' insert-last-word '^[_' insert-last-word

autoload_zle incarg
bindkey -M viins '^X^a' incarg
bindkey -M vicmd '^X^a' incarg
# bindkey -M viins -s '^X^x' '^[-1^X^a'
# bindkey -M vicmd -s '^X^x' '^[-1^X^a'
# bindkey -s '^X^x' '^[-1^X^a'

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
	if [[ -v _accept_line_rerun && -z $BUFFER ]]; then
		BUFFER=r
	elif [[ $BUFFER = r ]]; then
		_accept_line_rerun=
	else
		unset _accept_line_rerun
	fi
	zle .accept-line
}
zle -N accept-line

bindkey -M viins '^L' run-chpwd

# Menuselect
function _accept-and-hold-update() {
	zle accept-and-hold
	zle menu-select
}
zle -N _accept-and-hold-update
bindkey -M menuselect '=' accept-and-infer-next-history
bindkey -M menuselect 'a' accept-and-hold
bindkey -M menuselect '+' accept-and-hold
bindkey -M menuselect 'b' _accept-and-hold-update

zle -N incremental-complete-word
bindkey '^Xi' incremental-complete-word

# bindkey -M menuselect '^[' vi-insert
bindkey -M menuselect '^M' .accept-line
# bindkey -s -M menuselect 'b' 'a^X^M'

# zle -C complete-menu menu-select _generic
# complete_menu() {
	# setopt localoptions alwayslastprompt
#		zle menu-select
# }
# zle -N complete_menu
bindkey '^X^M' menu-select
bindkey '^Xm' menu-select
bindkey -M viins '^Xl' list-expand
bindkey -M viins '^X*' expand-word

bindkey -s -M menuselect j $terminfo[kcud1]
bindkey -s -M menuselect k $terminfo[kcuu1]
bindkey -s -M menuselect l $terminfo[kcuf1]
bindkey -s -M menuselect h $terminfo[kcub1]

autoload -Uz run-help
unalias run-help
autoload -Uz run-help-{git,ip,openssl,p4,sudo,svk,svn}

# zle -N self-insert paste-magic
autoload -Uz paste-magic
zle -N bracketed-paste paste-magic

ZSH_AUTOSUGGEST_MANUAL_REBIND=true
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# # highlight dangerous commands
# typeset -A ZSH_HIGHLIGHT_PATTERNS=(
# 	'rm -rf *' 'fg=white,bold,bg=red'
# )
# ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
# source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
# add-zsh-hook chpwd chpwd_recent_dirs

unfunction autoload_zle

set -o ignore_eof
function zle_exit() {
	zle .reset-prompt
	if [[ -n $zsh_scheduled_events ]]; then
		print "zsh: you have scheduled events."
	elif [[ -o login ]]; then
		read -esrq "?zsh: surely exit? " && exit
	else
		exit
	fi

	zle redisplay
	return
}

zle -N zle_exit
bindkey '^D' zle_exit
