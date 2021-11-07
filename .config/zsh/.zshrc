#!/usr/bin/zsh
() {
	typeset -ga fpath
	fpath=($ZDOTDIR/*(/) $fpath)

	typeset i # We are lazi.
	local f
	for f ($ZDOTDIR/??-*.zsh) source $f
}

# This tricky shit has to be set from here.
setopt print_exit_value
