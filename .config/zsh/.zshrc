#!/usr/bin/zsh
fpath=($HOME/.config/zsh/ $HOME/.config/zsh/Completion $HOME/.config/zsh/Zle $fpath)

# interesting: dynamic directory names
# https://superuser.com/questions/751523/dynamic-directory-hash
# https://vincent.bernat.ch/en/blog/2015-zsh-directory-bookmarks

for f ($ZDOTDIR/??-*.zsh) source $f
