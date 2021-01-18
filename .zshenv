path=($HOME/.local/bin $path $HOME/.cargo/bin)
export ZDOTDIR=$HOME/.config/zsh

case $TTY in
/dev/tty1) # X11 session
	export BROWSER=firefox
	export TERMINAL=alacritty
	;;
*)
	export BROWSER=lynx
	;;
esac

export LANG=en_US.UTF-8
export TZ=:Europe/Budapest

export GNUPGHOME=$HOME/.config/gnupg
