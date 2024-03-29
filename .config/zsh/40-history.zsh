HISTFILE=$XDG_RUNTIME_DIR/zhistory
HISTSIZE=10000
SAVEHIST=10000

setopt append_history
setopt bang_hist
setopt hist_expire_dups_first
setopt hist_fcntl_lock
setopt hist_find_no_dups
setopt hist_ignore_{dups,all_dups,space}
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

	typeset -a words=( ${(zA)1} )
	# ( cmd ';' )
	if (( $#words == 2 && $#words[1] <= 4 )); then
		return 2
	fi

	case $words[1] in
	rm|rmdir|poweroff|reboot|exit|run-help)
		return 1 ;;
	man|zathura|where|which|license|emv|eln|sdir|vidir)
		return 2 ;;
	git)
		# ( cmd [ git ] ';' )
		if (( $#words <= 3 )); then
			return 2
		fi
		case $words[2] in
		show) return 2 ;;
		esac
		;;
	esac

	return 0
}
