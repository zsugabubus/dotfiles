umask 027

# xkbcomp -I$HOME/.config/xkb $HOME/.config/xkb/keymap/custom.xkb $DISPLAY # &&
# nice -10 xcape -e "Hyper_L=space;Control_L=Escape;Caps_Lock=Escape"

if [[ -z $DISPLAY ]] && [[ $XDG_VTNR = 1 ]]; then
	# Disable pinentry on login tty.
	export GPG_TTY=-

	export XAUTHORITY=${XDG_RUNTIME_DIR:?}/Xauthority
	# Avoid warning about nonexisting file.
	touch $XAUTHORITY

	xauth add :0 . `mcookie`
	#exec startx -- -ardelay 200 -arinterval 34
	export DISPLAY=:0
	(
		inotifywait -rmqe CREATE -t 1 /tmp 2>/dev/null | awk '/\/tmp\/.X11-unix\/X0/{exit}'
		exec env -u SHLVL i3 # -c /home/$USER/mem/i3con -Vd all 2>/tmp/i3err >/tmp/i3log
	) &!

	trap 'exec env -u SHLVL i3' USR1
	# Ignore signal, so Xserver will notify us when ready to accept connections.
	# See Xserver(1).
	# trap '' USR1

	# (
		trap '' USR1
		X $DISPLAY vt$XDG_VTNR -ac -background none -keeptty -novtswitch -ardelay 200 -arinterval 34
	# ) &
	# wait

	# Wait for SIGUSR1 to arrive.
	# wait

	logout
# 1) # Start Wayland/Sway.
#		if [[ -z "$WAYLAND_DISPLAY" ]]; then
#			exec env RUST_BACKTRACE=1 sway -d 2>>/tmp/swayerr.txt
#		fi
#		;;
else
	setleds +num 2>/dev/null
fi

# if [[ "$XDG_VTNR" == 2 ]]; then
#  nice -10 xcape -e "Hyper_L=space;Control_L=Escape;Caps_Lock=Escape"
# fi

	# [[ -z "$DISPLAY" ]] && export DISPLAY=':0'
	# # [[ -z "$WAYLAND_DISPLAY" ]] && export XDG_RUNTIME_DIR='/var/run/user/1000' WAYLAND_DISPLAY='wayland-0'
	# [[ -z "$TMUX" ]] && tmux
# fi
