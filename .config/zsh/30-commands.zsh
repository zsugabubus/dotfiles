zmodload zsh/sched
zmodload -F zsh/stat b:zstat

autoload -Uz open

setopt aliases

# Pure aliases. (Little enhancements.)

alias -g L='|& '$PAGER
alias -g V='|& '$EDITOR

alias -s {{c,h}{,pp,++},rs,txt,vim,diff}=open
alias -s {bmp,jpg,png}=open
alias -s {avi,mp{0,3,4},mkv}=open
alias -s {pdf,ps}=open

alias -- -=cd\ -
for i ({0..9}) alias -- -$i=cd\ -$i

alias a=aria2t
alias abduco='ABDUCO_SOCKET_DIR=$XDG_RUNTIME_DIR abduco'
alias am='alsamixer'
alias bc='bc -lq'
alias cal='cal -m'
alias cp='cp -i'
alias curl='noglob curl --compressed'
alias d='dirs -v'
alias df='df -h'
alias diff='diff --color=auto'
alias diff='diff -upZ'
alias dmesg='dmesg -H --color=always | less'
alias dn='DOTNET_CLI_TELEMETRY_OPTOUT=1 ht dotnet'
alias e=$EDITOR
alias f=zfiles
alias ffmpeg='ffmpeg -hide_banner'
alias ffplay='ffplay -hide_banner'
alias ffplayq='ffplay -hide_banner -nodisp -autoexit -loglevel quiet'
alias ffprobe='ffprobe -hide_banner'
alias fr='free -hwt'
alias g='git'
alias git='noglob git'
alias grep='grep --color=auto'
alias hh='HOME=$PWD'
alias ht='HOME=${TMPDIR:-/tmp}'
alias iftop='sudo -E iftop'
alias info='info --vi-keys'
alias info_all='() { info --subnodes "$@" }'
alias j='jobs'
alias l='ls-color -ohtrvF --group-directories-first --color=tty --quoting-style=literal'
alias la='l -A'
alias mdp='mdp -fi'
alias mv='mv -i'
alias node='NODE_REPL_HISTORY= node' # Disable persistent history.
alias o=open
alias pkill='pkill -x'
alias pm='progress -M'
alias readelf='readelf -W'
alias rm='rm -dI --one-file-system'
alias tree='tree-color'
alias vlock_all='nice -20 vlock -a'
alias yt=youtube-dl

alias pl='pass login'
compdef '_files -W ~/.config/passwords' pl

# Complex commands.

alias asm='gcc -fno-stack-protector -fno-asynchronous-unwind-tables -S'
alias configure_make='./configure && make'
alias cpd='() { rsync -aihPv -- $^*/ }'
alias du..='du --apparent-size -chd 1 . | sort -h'
alias du.='du --apparent-size -csh . | sort -h'
alias fm='findmnt --real -o TARGET,SOURCE,FSTYPE,SIZE,USED,AVAIL,USE%,OPTIONS'
alias ipt='sudo iptables -xvL --line-numbers | sed '"'"'s/^Chain \(\S\+\)/Chain \x1b[1m\1\x1b[0m/'"'"
alias make='nice -n15 make -j2'
alias mktarget='() { mkdir -p -- $@:P }'
alias oct='od -tu1'
alias oz='() { od -Aexpect x -t x1z -v "$@" | sed '"'"'s/  >\(.*\)<$/  |\1|/'"'"' }'
alias term='$TERMINAL >/dev/null &disown'
alias topp='() { top -p${^$(pidof $1)} }'
alias upnp='upnpc -u "http://router.lan:5000/rootDesc.xml"'

function gcd() {
	cd -- $(git rev-parse --show-toplevel)
}

function strace_show() {
	local tmp=/tmp/strace
	strace -fo $tmp "$@" && $EDITOR $tmp
}

function n() {
	local args=()
	if test -d inbox/cur; then
		args+=(-f inbox)
	elif test -d cur; then
		args+=(-f .)
	fi
	neomutt $args
}

function gccc() {
	gcc -O2 -Wall -Wextra -pthread -march=native -std=c11 -g -ldl -lm main.c &&
	time ./a.out
}

function gccd() {
	gcc -O0 -march=native -std=c11 -g -ldl main.c $* &&
	gdb ./a.out -ex run
}

function make_install() {
	local prefix
	for prefix in '' sudo; do
		$prefix make PREFIX=/usr prefix=/usr install && break
	done
}

alias mpv_cam='() { mpv "av://v4l2:/dev/video${1:-0}" }'
alias mpv_test='mpv --input-test --force-window --idle'
alias mp='() { mpv 2>/dev/null --player-operation-mode=pseudo-gui ${*:-.} &! }'
compdef mp=mpv_hack
alias mpm='() { eval mp "*(m-${1:-1}/)" }'
compdef mpm=mpv_hack
alias mpn='() { eval mp "*(.om[1,${1:-100}])" }'
compdef mpn=mpv_hack
alias mpc='mpv --player-operation-mode=cplayer --no-video'
compdef mpc=mpv_hack

function mo() {
	local dev=$(
		setopt pipe_fail
		lsblk -rpno TYPE,HOTPLUG,NAME,SIZE,LABEL,MOUNTPOINT |
		grep 'part 1' |
		fzf -1 |
		awk -F ' ' '{print $3}'
	) &&
	{
		read -srq "?mount $dev /mnt? [Y/n]"
	} always {
		print
	} &&
	sudo mount $dev /mnt
}

function clean() {
	for cmd in '' '-delete'; do
		find \( -empty -o -name '.deleted' -o -name '*.part' \) $cmd &&
		[[ -z $cmd ]] && read -srq '?Delete? ' && continue
		return
	done
}

function catf() {
	local f
	for f in ${@:-*(.)}; do
		printf '=== %s ===\n' ${(qq)f}
		(<$f)
		print
	done | less
}

function usb_rebind() {
	sudo tee /sys/bus/usb/drivers/usb/unbind <<<$1
	sudo tee /sys/bus/usb/drivers/usb/bind <<<$1
}

function pdfmerge() {
	local out=a.pdf
	command gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -sOutputFile="$out" ${@:-*.pdf}
}

function md() {
	mkdir -p -- $1 && cd -- $1
}

function rmdir() {
	if (( 1 < $# )); then
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

function unar() {
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
				cd ${f:r} &&
				while cd *; do :; done 2>/dev/null
				:
			fi
		}
	done
}
compdef '_files -g "*.(zip|rar|tar|tar.*)"' unar
function mkar.xz() { tar cavf $1.tar.xz "$@" }
function mkar.gz() { tar cavf $1.tar.gz "$@" }
function mkar.zip() { zip -r $1.zip "$@" }
alias mkar=mkar.gz

function difforig() {
	diff ${1%%.orig}.orig ${1%%.orig}
}
compdef '_files -g "*.orig"' difforig

alias www='() { if [[ 1 == $# ]]; then www $1; else www - : -- tar -cf - $*; fi } '
alias timer='() { ( sleep ${1:-5m} && ~/doc/cuckoo-clock.mp3 ) &! }'

autoload -U zmv
alias mvv='noglob __zmv -M'
function __zmv() {
	zmv -nvW "$@" &&
	{ read -srq "?Execute? " } always { print } &&
	zmv -vW "$@"
}

function flat() {
	if [[ -d $1 ]]; then
		mv -- $1/(.*|*)(N) . && rmdir -p -- $1
	fi
}

alias cdtarget='() { cd ${~1:P}; }'
compdef '_files -g "*(@-/)"' cdtarget
alias rcd='() { (( $# > 0 )) && cd -- $1; while cd -- * 2>/dev/null; do :; done; }'

function sheep_pacman() {
	# --noconfirm does ask confirmation for conflicting packages.
	sheep 'yes | pacman -Sy '$*' && su $USER'
}

function sheep_black() {
	sheep \
		curl -o /tmp/strap.sh https://blackarch.org/strap.sh '&&' \
		echo 9c15f5d3d6f3f8ad63a6927ba78ed54f1a52176b /tmp/strap.sh '|' sha1sum -c '&&' \
		chmod +x /tmp/strap.sh '&&' \
		sudo /tmp/strap.sh '&&' \
		pacman -S --noconfirm $* '||: ; ' \
		su $USER
}

local function check_user_files() {
	if ! find -H ~m -mindepth 1 -name '.*' -prune -o -empty -o -type f -print -quit | awk '{exit 1}'; then
		print -rP "%F{yellow}%Bwarning:%f%b ~m is not empty."
		tree -C ~m | less
	fi
	for prog in in abduco tmux nvim firefox; do
		if pgrep -ax $prog &>/dev/null; then
			print -rP "%F{red}%Berror:%f%b $prog is running"
			return 1
		fi
	done
	if ! { sync && sync }; then
		print -rP "%F{red}%Berror:%f%b sync failed."
		return 1
	fi
}
local function confirm_cmd() {
	print -rnP "%B%F{blue}::%f Confirm? [y/N]%b " &&
	read -srq && command "${@}"
}
function poweroff() {
	check_user_files && confirm_cmd $0 "$@"
}
function reboot() {
	check_user_files && confirm_cmd $0 "$@"
}

function az() {
	exec ab
}

function ab() {
	local session
	if [[ -n "$1" ]] && ! which "$1" &>/dev/null; then
		session="$1"
		shift
	else
		session=$(tr </dev/urandom -dc a-z | head -c3)
	fi
	abduco -c "$session" "${@:-$SHELL}"
}

# Jumping from one abduco to another.
function rabbit() {
	while session=$(
		abduco -l |
		awk "-vq=$session" 'NR == 1 { print > "/dev/tty" } 1 < NR { print | "fzf --query=" q "" }' |
		sed 's/[^\t]*\t[^\t]*\t//'
	) &&
	test -n "$session" &&
	abduco -A $session "$SHELL"
	do
	done
}

function br() {
	bwrap \
		--unsetenv SHLVL \
		--ro-bind / / \
		--tmpfs /tmp \
		--dev /dev \
		--proc /proc \
		--tmpfs /home \
		--dir /home/user \
		--bind ${${:-~m}:A} /home/user \
		--unshare-all \
		--hostname host \
		--die-with-parent \
		--as-pid-1 \
		--chdir /home/user \
		-- ${*:-/$SHELL}
}

function bwsh() {
	bwrap \
		--unsetenv SHLVL \
		--ro-bind / / \
		--dev /dev \
		--proc /proc \
		--tmpfs /tmp \
		--bind ${${:-~m}:A}{,} \
		--bind ${${:-~/.local/share/nvim/undo}:A}{,} \
		--bind $PWD:A{,} \
		--tmpfs ~/.config/passwords \
		--unshare-{user,ipc,pid,uts,cgroup} \
		--hostname bubble \
		--die-with-parent \
		--as-pid-1 \
		--chdir $PWD \
		/$SHELL
}

function M() {
	[[ $PWD/ =~ ^${:-~m}/ ]] || cd -q -- ~m
	bwsh
}

function print_composekeys() {
	less "/usr/share/X11/locale/$(grep --max-count=1 "${LANG%.*}.UTF-8\$" /usr/share/X11/locale/locale.dir | cut -d/ -f1)/Compose"
}

function rs() {
	pkill redshift
	redshift -x
	redshift -b 0.$1 -o
}

local tmux_leave_shell
if [[ -o login ]]; then
	tmux_leave_shell=''
else
	tmux_leave_shell='exec '
fi
alias t="${tmux_leave_shell}tmux attach"
alias tn="${tmux_leave_shell}tmux new -s \$PWD:t"

alias pub=publish
function publish() {
	case $# in
	(0)
		echo "minidlna: $(systemctl --user is-active minidlna.service)"
		command ls -C --color ~/pub
		;;
	(1)
		case $1 in
		(start|stop)
			systemctl --user $1 minidlna
			return
			;;
		esac
		;&
	(*)
		ln -sit ~/pub $@:a
		;;
	esac
}
compdef '_files' publish

function webfs() {
	readonly port=${1:-8080} auth=$2
	if (( $(id -u) )); then
		print -rP "%B%F{red}error:%f%b you cannot perform this operation unless you are root."
		return 1
	fi
	{
		print -rP "%B%F{blue}::%f Adding iptables rule...%b"
		iptables -I NEW_TCP -p tcp --dport $port -j ACCEPT
		print -rP "%B%F{blue}::%f Listening on port $port...%b"
		nice -n7 webfsd -Fp $port -t3 -a0 -R. -findex.html -nlocalhost ${auth:+-b$auth}
	} always {
		print -rP "%B%F{blue}::%f Deleting iptables rule...%b"
		iptables -D NEW_TCP -p tcp --dport $port -j ACCEPT
	}
}

function genm3u() {
	print -l *.{mp3,mp4,mkv}(N) >$PWD:t.m3u
}

function spek() {
	for f; do
		() {
			ffmpeg -i $2 -lavfi showspectrumpic=s=1024x512:color=rainbow -c:v png -f image2pipe -y $1 &&
			feh $1
		} =() $f
	done
}

function pacman_history() {
	expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort | tail -n ${1:-20}
	# pacman -Qie | awk -F'\\s+:\\s+' '"Name" == $1 { name=$2 } "Install Date" == $1 { "date -d\"" $2 "\" -u +%Y-%m-%d\\ %R" | getline date; printf "%-40s %s\n", name, date }' | sort -t' ' -k2 -r
}

function gnuplot_stdin() {
	gnuplot --persist -e "plot '/dev/stdin';"
}

function chromium_clean() {
	rm -rf .cache/chromium .config/chromium/Default/Service\ Worker
}

# https://zsh.sourceforge.io/Contrib/scripts/users/bs/show
function files() {
	typeset -g files
	files=( $~* )
	print -rc $files
}
alias	files='noglob files'

autoload -Uz ${:-$ZDOTDIR/Misc/*(.:t)}

function command_not_found_handler() {
	print -u2 -r "zsh: command not found: ${(q)1}.  This incident will be reported."
	return 127
}

TIMEFMT='%J  %U user %S system %P cpu %*E total %MkB max %R faults'
REPORTTIME=1

alias -g There='~[here]'
alias -g Tmux='~[tmux-pane]'

typeset -g _ZSH_HERE_FILE=$XDG_RUNTIME_DIR/.zhere
function here() {
	print >$_ZSH_HERE_FILE -- $PWD
	printf 'There=%q\n' There
}

add-zsh-hook -Uz zsh_directory_name tmux_directory_name
add-zsh-hook -Uz zsh_directory_name here_directory_name

DIRSTACKSIZE=10

local function __zle-chpwd() {
	(( __zfiles_active )) && return
	dirs -v

	# Auto-ls small directories only.
	local -A stat
	zstat -sNH stat -F '' -- . 2>/dev/null &&
	(( ${stat[size]} <= 4096 )) &&
	l
}
add-zsh-hook chpwd __zle-chpwd
