autoload -Uz promptinit &&
promptinit

read -r DEFAULT_USER <~/.config/.username
read -r DEFAULT_HOST <~/.config/.hostname

prompt powerline $DEFAULT_USER $DEFAULT_HOST

unset DEFAULT_USER
unset DEFAULT_HOST
