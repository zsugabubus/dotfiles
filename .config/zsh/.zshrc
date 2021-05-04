#!/usr/bin/zsh
fpath=($HOME/.config/zsh/ $HOME/.config/zsh/Completion $HOME/.config/zsh/Zle $fpath)

# interesting: dynamic directory names
# https://superuser.com/questions/751523/dynamic-directory-hash
# https://vincent.bernat.ch/en/blog/2015-zsh-directory-bookmarks

source $ZDOTDIR/terminal.zsh
source $ZDOTDIR/session.zsh
source $ZDOTDIR/completion.zsh
source $ZDOTDIR/commands.zsh
source $ZDOTDIR/history.zsh
source $ZDOTDIR/prompt.zsh
source $ZDOTDIR/theme-current.zsh
source $ZDOTDIR/zle.zsh
source $ZDOTDIR/builtin.zsh

if [[ -o interactive ]]; then
	if [[ ! -o single_command && ! $0 = command ]]; then
		if [[ ! $PWD = ~ ]]; then
			if [[ $PWD = $XDG_RUNTIME_DIR/mem ]]; then
				cd ~m
			else
				l
			fi
		fi
	fi
fi
