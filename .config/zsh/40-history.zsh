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

	# 0: Remember.
	# 1: Forget immediately.
	# 2: Internal history only.

	case ${words[1]} in
	man|rm|poweroff|reboot|exit|where)
		return 1 ;;
	zathura)
		return 2 ;;
	esac

	return 0
}
