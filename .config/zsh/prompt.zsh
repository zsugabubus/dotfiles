autoload -Uz promptinit &&
promptinit

read DEFAULT_USER <~/.config/.username
read DEFAULT_HOST <~/.config/.hostname

prompt powerline $DEFAULT_USER $DEFAULT_HOST

unset DEFAULT_USER
unset DEFAULT_HOST
