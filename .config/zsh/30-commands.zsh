zmodload zsh/sched
zmodload -F zsh/stat b:zstat

autoload -Uz open

setopt aliases

alias -- -=cd\ -
integer i
for i ({0..9}) alias -- -$i=cd\ -$i

alias cp='cp -i'
alias cpd='() { rsync -aihPv -- $^*/ }'
alias d='dirs -v'
alias df='df -h'
alias diff='diff --color=auto -upZ'
alias f=zfiles
alias grep='grep --color=auto'
alias l='ls-color -ohtrvF --group-directories-first --color=tty --quoting-style=literal'
alias la='l -A'
alias mv='mv -i'
alias pm='progress -M'
alias tree=tree-color
alias vd=vidir

alias e=$EDITOR
compdef e=$EDITOR
alias e..='e ***(.)'

alias g=git
compdef g=git
alias git='noglob git'

function ga() {
	local f
	while f=$(
		git ls-files -z --others --exclude-standard |
		fzr --exit-0 --read0 --print0 --reverse
	); do
		git add -v -- ${(ps:\0:)f}
	done
}

function gb() {
	git switch $(git branch --format '%(refname:short)' | fzr -r)
}

function md() {
	mkdir -p -- $1 && cd -- $1
}

function mktarget() {
	local args=( ${@:-*(-@)} )
	mkdir -p -- $args:P
}

function mkbuild() {
	ln -sT ${TMPDIR:-/tmp}/build-${${:-.}:a:t} build
	mkdir -p -- ${${:-build}:P}
}

function rm() {
	if (( ! ${@[(I)-*]} && 2 <= $# )) && [[ ! -e ${@[-1]} || -d ${@[-1]} ]]; then
		read 2>&1 -q '?zsh: rm: does not seem like an rm; surely continue? [y/N] ' ||
		return 100
	fi
	command rm -dI --one-file-system $@
}

function rmdir() {
	if (( $# )); then
		command rmdir "$@"
	else
		local dirname=${PWD:t}
		cd -q -- ${PWD:h} &&
		if command rmdir -- $dirname; then
			cd .
		else
			cd $dirname
		fi
	fi
}

function catrm() {
	local f
	for f; do
		echo
		cat -- $f
		rm -i -- $f
	done
}

autoload -U zmv
alias sdir='noglob __zmv -M'
function __zmv() {
	emulate -L zsh
	zmv -nvW "$@" &&
	{ read -srq "?Execute? " } always { print } &&
	zmv -vW "$@"
}

function emv() {
	(( $# )) || set -- *(N)

	local f=
	for f; do
		local dst=$f
		vared -e dst &&
		mkdir -p -- $dst:h &&
		mv -i -v -- "$f" "$dst"
	done
}

function eln() {
	emulate -L zsh
	zmodload -F zsh/stat b:zstat
	zmodload zsh/system

	local f=
	typeset -A stat

	for f; do
		stat=()
		if zstat -LNH stat -F '' -- $f && [[ ${stat[mode]:0:1} != 'l' ]]; then
			printf '%s: not a link\n' "$f"
			continue
		fi

		local target=$stat[link]
		vared -ep '${(q)f:t} -> ' target &&
		ln -sfn "$target" "$f"
	done
}

function flat() {
	if [[ -d $1 ]]; then
		mv -- $1/(.*|*)(N) . && rmdir -p -- $1
	fi
}

alias cdtarget='() { cd ${~1:P}; }'
compdef '_files -g "*(@-/)"' cdtarget

function cd() {
	if (( $# == 1 )) && [[ -f $1 ]]; then
		local tmp
		printf -v tmp 'e %q' $1:t
		print -z -- $tmp
		set -- $1:h
	fi
	builtin cd "$@"
}

function gcd() {
	cd -- "$(git rev-parse --show-toplevel)"
}

function du() {
	command du -bchd 1 ${@:-.} | sort -h
}
function du.() {
	du *(.)
}

function unar un() {
	for f; do
		case $(file --mime-type -b -- $f) in
		application/zip)
			unzip $f -d ${f:r} ;;
		application/x-rar)
			unrar x $f ;;
		*)
			mkdir -p ${f:r} && tar xavf $f -C ${f:r} ;;
		esac &&
		{
			[[ -f $f ]] && rm -i $f
			if (($# == 1)); then
				builtin cd -- ${f:r} &&
				while builtin cd -- *; do :; done 2>/dev/null
				:
			fi
		}
	done
}
compdef '_files -g "*.(zip|rar|tar|tar.*)"' unar
function mkar.xz() { tar cavf $1.tar.xz "$@" }
function mkar.gz() { tar cavf $1.tar.gz "$@" }
function mkar.zip() { zip -r $1.zip "$@" }

function h. head.() {
	head *(.)
}

function difforig() {
	diff ${1%%.orig}.orig ${1%%.orig}
}
compdef '_files -g "*.orig"' difforig

function v() {
	tree -C | e -c 'setlocal nolist' -c AnsiEsc
}

function gccc() {
	gcc -O2 -Wall -Wextra -pthread -march=native -std=c11 -g -ldl -lm main.c &&
	time ./a.out
}

function gccd() {
	gcc -O0 -march=native -std=c11 -g -ldl main.c $* &&
	gdb ./a.out -ex run
}

function term() {
	$TERMINAL >/dev/null &!
}

function zathura() {
	command zathura --fork ${@:-*.pdf(om[1,1])}
}

function im() {
	local font_file=$(fc-match monospace -f '%{file}')
	feh \
		--scale-down \
		--image-bg black \
		--draw-filename \
		--draw-actions \
		--font ${font_file:t}/13 \
		--fontpath ${font_file:h} \
		"$@"
}

alias j='jobs'
alias pkill='pkill -x'
alias utop='top -u $USER'

function topp() {
	top -p${^$(pidof "$@")}
}

function fkill() {
	emulate -L zsh
	setopt err_return pipe_fail

	local line=$(
		ps fx -o pid,tty,stat,time,pcpu,command |
		fzr --header-lines=1
	)
	[[ $line =~ '([0-9]+)' ]]
	local pid=${match[1]}

	print -z "kill $pid"
}

alias am='alsamixer'

function arecord_loop() {
	arecord -Dloop -fFLOAT_LE -c2 "${@:--}"
}
function mpv_to_loop() {
	ALSA=loop mpv "${@:-.}"
}
function loop_to_rtp() {
	ffmpeg -re \
		-f alsa -acodec pcm_f32le -i loop \
		-acodec libmp3lame -ac 2 -ab 320k -ar 44100 -f rtp "rtp://${1?Missing server address}"
}
function rtp_play() {
	ffplay rtp://0
}

function spek() {
	for f; do
		() {
			ffmpeg -i $2 -lavfi showspectrumpic=s=1024x512:color=rainbow -c:v png -f image2pipe -y $1 &&
			nsxiv $1
		} =() $f
	done
}

function rs() {
	local args=()
	if [[ $1 = day ]]; then
		shift
		args+=(-t6500:5000)
	fi

	if (( !$# )); then
		redshift -x
	else
		args+=(-b 0.$1)
		redshift -Po $args
	fi
}

function light() {
	local dir
	for dir in /sys/devices/*/*/drm/**/intel_backlight; do
		integer max_brightness=$(< $dir/max_brightness)
		integer wanted_brigtness=$(( ${1:-100} * max_brightness / 100 ))
		echo $wanted_brigtness | sudo tee $dir/brightness
	done
}

alias fm='findmnt --real -o TARGET,SOURCE,FSTYPE,SIZE,USED,AVAIL,USE%,OPTIONS'
alias fr='free -hwt'
alias hh='HOME=$PWD'
compdef hh=-
alias ht='HOME=${TMPDIR:-/tmp} XDG_RUNTIME_DIR=${TMPDIR:-/tmp}'
compdef ht=-
alias ssh='noglob ssh'
alias systemctl='noglob systemctl'
alias vlock='nice -20 vlock'

function M() {
	local opt_with_net opt_with_gpu opt_with_docker opt_user=(user) opt_host=(bubble) opt_cwd=(${PWD?})
	zparseopts -D -F -K -- n=opt_with_net g=opt_with_gpu d=opt_with_docker u:=opt_user h:=opt_host C:=opt_cwd || return 1
	local new_user=$opt_user[-1]
	local new_host=$opt_host[-1]
	local new_home=/home/$new_user
	local new_cwd=$opt_cwd[-1]
	bwrap \
		--as-pid-1 \
		--die-with-parent \
		--unshare-all \
		${opt_with_net:+--share-net} \
		--hostname "$new_host" \
		--uid "${UID?}" \
		--gid "${GID?}" \
		--clearenv \
		--setenv DISPLAY "$DISPLAY" \
		--setenv HOME "$new_home" \
		--setenv USER "$new_user" \
		--setenv PATH '/usr/local/bin:/usr/bin' \
		--setenv TERM "${TERM:-dummy}" \
		--dev /dev \
		--proc /proc \
		--tmpfs /tmp \
		--ro-bind /bin{,} \
		--ro-bind /usr{,} \
		--ro-bind /lib{,} \
		--ro-bind /lib64{,} \
		--ro-bind-data 3 /etc/group \
		3<<<"$new_user:x:$UID:" \
		--ro-bind-data 4 /etc/passwd \
		4<<<"$new_user:x:$UID:$GID::$new_home:$SHELL" \
		${=opt_with_gpu:+--ro-bind /sys{,}} \
		${=opt_with_gpu:+--ro-bind /dev/dri{,}} \
		${=opt_with_net:+--ro-bind /etc/ssl{,}} \
		${=opt_with_net:+--ro-bind /etc/fonts{,}} \
		${=opt_with_net:+--ro-bind /etc/hosts{,}} \
		${=opt_with_net:+--ro-bind /etc/resolv.conf{,}} \
		${=opt_with_net:+--ro-bind /etc/ca-certificates{,}} \
		${=opt_with_docker:+--ro-bind /var/run/docker.sock{,}} \
		--ro-bind ~m $new_home/mem \
		--ro-bind {~,$new_home}/.config/git \
		--ro-bind {~,$new_home}/.config/zsh \
		--ro-bind {~,$new_home}/.zshenv \
		--ro-bind {~,$new_home}/.dir_colors \
		--ro-bind {~,$new_home}/.XCompose \
		--ro-bind {~,$new_home}/.cache/zsh \
		--ro-bind {~,$new_home}/.cache/zcompdump \
		--bind "$PWD" "$new_cwd" \
		--chdir "$new_cwd" \
		-- ${*:-$SHELL}
}

function pacman_history() {
	expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort | tail -n ${1:-20}
}

function poweroff reboot() {
	tree -L 2 -C ~m | less -r &&
	! ps -f -C nvim -C firefox -C transmission-daemon &&
	sync &&
	print -rnP "zsh: confirm? [y/N]%b " &&
	read -srq &&
	sudo "$0"
}

function usb_rebind() {
	sudo tee /sys/bus/usb/drivers/usb/unbind <<<$1
	sudo tee /sys/bus/usb/drivers/usb/bind <<<$1
}

alias curl='noglob curl --compressed'
alias curltor='curl -x socks5h://127.1:9050'
alias iftop='sudo -E iftop'
alias ip='ip -c'
alias ipt='sudo iptables -xvL --line-numbers | sed '"'"'s/^Chain \(\S\+\)/Chain \x1b[1m\1\x1b[0m/'"'"

function speedtest() {
	emulate -L zsh
	trap return INT

	() {
		print -P "\n%B%F{blue}::%f Upload %F{blue}::%f%b"
		curl -T /dev/zero http://speedtest.tele2.net/upload.php -o /dev/null
	}
	() {
		print -P "%B%F{blue}::%f Download %F{blue}::%f%b"
		curl http://speedtest.tele2.net/1GB.zip -o /dev/null
	}
}

function ping() {
	command ping "${@:-1.1.1.1}"
}

function iptables_accept_tcp() {
	sudo iptables -I NEW_TCP -p tcp --dport ${1?Port missing} -j ACCEPT
}

function t() {
	tmux attach-session
}
function tn() {
	tmux -N new-session -s "${${PWD:t}//$USER/home}"
}
function tnt() {
	tmux -N \
		new-session -t "$(tmux display-message -p '#S')" \;\
		set-option -s destroy-unattached on
}

alias cal='cal -m'
alias dc='BUILDKIT_PROGRESS=plain docker compose'
alias dn='DOTNET_CLI_TELEMETRY_OPTOUT=1 ht dotnet'
alias info='info --vi-keys'
alias info_all='info --subnodes'
alias oct='od -tu1'
alias remind='remind -m -b1'
alias tr='ARGV0=transmission-tui luajit ~c/transmission/transmission-tui'
alias tra='ARGV0=transmission-admin node ~c/transmission/transmission-admin'
alias yt=yt-dlp
alias yts='yt --write-subs --write-auto-subs'

function ca() {
	remind -cu -w$COLUMNS,0,1 "$@" ~c/remind |
	sed 's/\xe2\x80\x8e//g;s/\x0c//' |
	less
}

function can() {
	cal
	remind -n ~c/remind | sort
}

function pc() {
	python -qic 'from math import *'
}

function strace_show() {
	local tmp=/tmp/strace
	strace -fo $tmp $@ && $EDITOR $tmp
}

function node() {
	NODE_REPL_HISTORY=$XDG_RUNTIME_DIR/nodehistory command node "$@"
}

function python() {
	PYTHON_HISTORY=$XDG_RUNTIME_DIR/python_history command python "$@"
}

alias ffmpeg='ffmpeg -hide_banner'
alias ffplay='ffplay -hide_banner'
alias ffplayq='ffplay -hide_banner -nodisp -autoexit -loglevel quiet'
alias ffprobe='ffprobe -hide_banner'

function mpv() {
	command mpv ${${${@:-.}/#--sort=/--script-opts=sort=}/#--nohup/--script-opts=hup=no}
}
alias mpv_cam='() { mpv "av://v4l2:/dev/video${1:-0}" }'
alias mpv_test='mpv --input-test --force-window --idle'
function mp() {
	mpv \
		--player-operation-mode=pseudo-gui \
		--force-window=immediate \
		${@:-.} \
		2>/dev/null \
		&!
}
compdef mp=mpv_hack
alias mp.='() { mp $@ -- *(.) }'
alias mp..='() { mp $@ -- ***(.) }'
alias mpm='() { eval mp "*(m-${1:-1}/)" }'
compdef mpm=mpv_hack
alias mpn='() { eval mp "*(.om[1,${1:-100}])" }'
compdef mpn=mpv_hack
alias mpc='mpv --player-operation-mode=cplayer --no-video'
compdef mpc=mpv_hack
function mpd() {
	ARGV0=mpd mpv 2>/dev/null --no-terminal --no-video ${@:-.}
}
alias mpom='mp --sort=no *(om)'
alias mpw='mp --force-window --idle'

function mpt() {
	ARGV0=mpt luajit ~c/mpv/mpt ${@:-/tmp/mpv*}
}

function mutt n() {
	set -- -n "$@"
	if [[ -d inbox/cur ]]; then
		set -- -f inbox "$@"
	elif [[ -d cur ]]; then
		set -- -f . "$@"
	fi
	local term=$TERM
	if [[ $term != linux ]]; then
		term=screen-256color
	fi
	TERM=$term command mutt -n "$@"
}
compdef n=mutt

function catty() {
	socat -u SYSTEM:"$*",openpty -
}

function gdbrun() {
	gdb -quiet ${1?} \
		-ex 'set confirm off' \
		-ex 'handle SIG32 noprint nostop' \
		-ex 'handle SIG34 noprint nostop' \
		-ex "run ${(jj j)${(qq)@:2}}"
}

function oz() {
	od -Aexpect x -t x1z -v $@ |
	sed 's/  >\(.*\)<$/  |\1|/'
}

function pdfmerge() {
	local out=a.pdf
	command gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -sOutputFile="$out" ${@:-*.pdf}
}

function cuckoo() {
	tmux display-popup -T 'zsh: sched' -b 'double' -h 10 -w 40 -E \
		sh -c 'printf "%s\n" "$*"; while ffplay -autoexit -nodisp ~/doc/cuckoo-clock.mp3 -loglevel error >/dev/null; do :; done' sh "$@"
}

function print_composekeys() {
	{
		cat "/usr/share/X11/locale/$(
			grep --max-count=1 "${LANG%.*}.UTF-8\$" /usr/share/X11/locale/locale.dir |
			cut -d/ -f1
		)/Compose"
		xmodmap -pke
	} | e
}

function pub publish() {
	ln -sit ~/pub $@:a
}
compdef '_files' publish

function genm3u() {
	print -l *.{mp3,mp4,mkv}(N) >$PWD:t.m3u
}

function gnuplot_stdin() {
	gnuplot --persist -e "plot '/dev/stdin';"
}

function chromium_clean() {
	test -d 'Safe Browsing' &&
	rm -rf Default/{Cache,Code\ Cache,Service\ Worker}
}

function pyman() {
	python -c "import $1; help($1)"
}

function sx start_x() {
	emulate -L zsh

	setopt nomonitor

	export GPG_TTY=- # Disable pinentry on login tty.

	export XAUTHORITY=${XDG_RUNTIME_DIR?}/Xauthority
	touch $XAUTHORITY

	export DISPLAY=:0

	trap '
		xauth generate $DISPLAY . trusted
		tmux new-session -d -s wm -c ~s/heawm-lua ./rc
	' USR1

	(
		trap '' USR1 &&
		exec X \
			$DISPLAY \
			vt$XDG_VTNR \
			-ac \
			-background none \
			-keeptty \
			-novtswitch \
			-noreset \
			-ardelay 200 \
			-arinterval 34
	) &

	wait
}

function zd() {
	zebra dark
}

function zl() {
	zebra light
}

autoload -Uz ${:-$ZDOTDIR/Misc/*(N.:t)}
