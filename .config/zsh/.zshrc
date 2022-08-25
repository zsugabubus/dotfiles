#!/usr/bin/zsh
() {
	typeset -ga fpath=($ZDOTDIR/*(/) $fpath)

	integer i # We are lazi.
	local f
	for f ($ZDOTDIR/??-*.zsh) source $f
}

setopt print_exit_value
