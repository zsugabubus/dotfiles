umask 027

# xkbcomp -I$HOME/.config/xkb $HOME/.config/xkb/keymap/custom.xkb $DISPLAY # &&

setleds +num 2>/dev/null

function start_wl() {
	export GPG_TTY=- # Disable pinentry on login tty.
	sway
}

function start_x() {
	export GPG_TTY=- # Disable pinentry on login tty.

	export XAUTHORITY=${XDG_RUNTIME_DIR:?}/Xauthority
	# Avoid warning about nonexisting file.
	touch $XAUTHORITY

	xauth add :0 . `mcookie`
	#exec startx -- -ardelay 200 -arinterval 34
	export DISPLAY=:0

	X $DISPLAY vt$XDG_VTNR -ac -background none -keeptty -novtswitch -noreset -ardelay 200 -arinterval 34
}
