#!/usr/bin/zsh
() {
	typeset -ga fpath=($ZDOTDIR/*(/) $fpath)

	local f
	for f ($ZDOTDIR/??-*.zsh) source $f
}

setopt print_exit_value
