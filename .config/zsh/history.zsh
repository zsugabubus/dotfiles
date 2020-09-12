HISTFILE="$XDG_RUNTIME_DIR/zhistory"
HISTSIZE=10000
SAVEHIST=10000

setopt append_history
setopt bang_hist
setopt hist_expire_dups_first
setopt hist_fcntl_lock
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_no_functions
setopt hist_no_store
setopt hist_reduce_blanks
setopt hist_save_no_dups
setopt hist_verify
unsetopt extended_history
unsetopt hist_beep

function zshaddhistory() {
	emulate -L zsh
	# ! $PWD/ =~ ^${:-~m}/ &&
	case ${${(z)1}[1]} in
	e)
		# Explicit save history.
		return 0 ;;
	zathura|man|kill|pkill|chmod|chattr|rm|rmdir|rd|mkdir|fd|mv[ve]|rmm|cpp|lnn|md)
		# Saved on the internal history only.
		return 2 ;;
	ab|abduco|tmux|?|ls|lt|where|publish|poweroff|reboot|exit|spek)
		# Do not save at all.
		return 1 ;;
	esac
}
