source $ZDOTDIR/hashes.zsh

autoload -Uz open

setopt aliases

function -() { cd - }

alias e="$EDITOR -p"
alias ed="$EDITOR -d"
alias eg="$EDITOR +Gstatus"

alias -s {{c,h}{,pp,++},rs,txt,vim,diff}=open
alias -s {bmp,jpg,png}=open
alias -s {avi,mp{0,3,4},mkv}=open
alias -s {pdf,ps}=open
alias -s zip=un
alias -s tgz=un
alias o=open

function mo() {
	local dev=$(lsblk -rpno TYPE,HOTPLUG,NAME,SIZE,LABEL,MOUNTPOINT | grep 'part 1' | fzf -1 | awk -F ' ' '{print $3}') &&
	{ read -q "?mount $dev /mnt? [Y/n]" } always { print } && sudo mount $dev /mnt
}
alias da='date'
alias configure_make='./configure && make'
alias make_install='() { for prefix in "" sudo; do $prefix make PREFIX=/usr prefix=/usr install && break; done }'
alias make='make -j$(($(nproc) + 1))'
alias make='make -j2'
alias h=man
alias ls='ls -ohtrF --group-directories-first --color=tty --quoting-style=literal'
alias l=ls
alias ll='ls -vl'
alias lt='\ls -ohtrF --color=tty --quoting-style=literal'
alias la='ll -A'
alias lc='ll -CA'
alias pkill='pkill -x'
alias d='dirs -v | head -10'
alias va='nice -20 vlock -a'
alias c-='cd -'
function catf() {
	local pre=''
	for f in ${@:-*}; do
		if [[ -f $f ]]; then
			printf $pre'%s:\n' $f
			pre='\n'
			cat -- $f
		fi
	done
}
function lll() { ls -l --color "$@" | less; }
alias tt=tarrtv
compdef tt=tarrtv
alias bo='bonsai | less -e'
function usbrebind() {
	sudo tee /sys/bus/usb/drivers/usb/unbind <<<$1
	sudo tee /sys/bus/usb/drivers/usb/bind <<<$1
}
function bonsai() {
	local prevlines=0 lines depth
	for depth in {2..$LINES}; do
		lines=$(tree -dL $depth 2>/dev/null | wc -l)
		if (( lines > $LINES || lines == prevlines )); then
			break
		fi
		prevlines=$lines
	done
	clear && tree -CdL $((depth - 1))
}

function un() {
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
compdef '_files -g "*.(zip|rar|tar|tar.*)"' un

function mkar.xz() { tar cavf $1.tar.xz $@ }
function mkar.gz() { tar cavf $1.tar.gz $@ }
function mkar.zip() { zip -r $1.zip $@ }

function speedtest() {
	setopt localtraps
	trap return INT
	() {
		print -P "%B%F{blue}::%f Download %F{blue}::%f%b"
		curl http://speedtest.tele2.net/1GB.zip -o /dev/null
	}
	() {
		print -P "\n%B%F{blue}::%f Upload %F{blue}::%f%b"
		curl -T /dev/zero http://speedtest.tele2.net/upload.php -o /dev/null
	}
}
compdef '_files -g "*.(png|jpg)"' feh
alias -g G='| grep -i'
alias -g F='| fzf | { while read f; do print -z $(q-@)f; done }'
alias -g _='| less'
alias diff='diff --color=auto'
alias gccc='gcc -O0 -g -ldl main.c && ./a.out'
alias df='df -h'
alias grep='grep --color=auto'
alias dmesg='dmesg -H --color=always | less'
alias readelf='readelf -W'
alias upnp='upnpc -u "http://router.lan:5000/rootDesc.xml"'
#alias tra="transmission-remote ${TR_HOST:-localhost}:${TR_PORT:-9091} ${TR_AUTH:+--authenv}"
alias diff='diff -upZ'
# alias imv='imv -d'
alias fm='findmnt --real -o TARGET,SOURCE,FSTYPE,SIZE,USED,AVAIL,USE%,OPTIONS'
alias grep='noglob grep'
alias rg='noglob rg'
alias rge='noglob _ripgrep_dashe'
alias frg='rg -F'
function _ripgrep_dashe() { rg -e "$*"; }
alias f='noglob ff'
alias f='noglob f'
function f() {
	find -mindepth 1 -iname $@ -printf '%P\0' 2>/dev/null |
	xargs -r0 --max-args=17 ls -1d --color |
	fzf -1 --ansi -d $'\xa0' -n2.. --ansi --multi --bind 'alt-enter:select-all,ctrl-o:execute($EDITOR {+2})' --preview 'stat {+2}' | {
		local files=()
		while IFS='\t' read; do
			files+=(${REPLY:2})
		done
		open $files
	}
}
function ff() {
	local iname=$1
	shift
	f *$iname* $@
}
function fkill() {
	local pid
	local args=()
	if (( UID != 0 )); then
		args=(-u $UID)
	fi
	ps $args -o pid,pcpu,state,time,command |
		awk "NR<2{print;next}{print | \"sort -rgk2\"}" |
		fzf -m --header-lines=1 -q "'" | awk '{print $1}' |
		xargs -r kill -${1:-9}
}
alias pot='ps uxf'
alias orig='() { cp -- $1 $1.orig; }'
alias difforig='() { diff ${1%%.orig}.orig ${1%%.orig} }'
compdef '_files -g "*.orig"' difforig
alias iftop='sudo -E iftop'
alias mdp='mdp -fi'
alias g='git'
alias j='jobs'
alias gs='git status'
alias gd='git diff'
alias am='alsamixer'
alias gds='git diff --staged'
alias GS='nvim +:Gstatus'
alias mpv_test='mpv --input-test --force-window --idle'
alias mp='() { mpv 2>&- --player-operation-mode=pseudo-gui ${*:-.} &! }'
compdef mp=mpv_hack
alias mpc='mpv --player-operation-mode=cplayer --no-video'
compdef mpc=mpv_hack
alias mpf='mp *(.)'
compdef mpf=mpv_hack
# function mpvs() { mpv --player-operation-mode=pseudo-gui "$1" --sub-file "${2:-/dev/null}" }
# compdef mpvs=mpv_hack
alias service='systemctl --user'

alias gdbrun='() { local file=$1; shift; gdb -quiet $file -ex "run ${(q)*}"; }'
autoload -U zmv
alias cpp='noglob _zmv -C'
alias lnn='noglob _zmv -L'
alias lnv='() { () { $EDITOR +"inoremap <C-n> <C-x><C-f>" +startinsert! -- $1 &&  ln -nTfsv $(<$1) $2; } =(readlink -- $1) $1 && ls; }'
compdef '_files -g "*(@)"' lnv
alias lne=lnv
compdef lne=lnv
alias flat='() { [[ -d $1 ]] && mv $1/.*(N) $1/*(N) . && rmdir $1 }'
alias mvv='noglob _zmv -M'
function _zmv() {
	zmv -nvW $@ && { read -q "?Execute? " } always { print } && zmv -vW $@
}
function mve() {
	local files=( ${@:-*} )
	() {
		$EDITOR +'normal zR' -d $1 $2 &&
		for precmd in echo ''; do
			local any=0
			exec 3<$1 4<$2
			while read -u 3 -r file &&
			      read -u 4 -r orig; do
				if [[ -z $file ]]; then
					$precmd rm -- $orig
					any=1
				elif [[ ! $file = $orig ]]; then
					$precmd mv -- $orig $file
					any=1
				fi
			done
			if (( ! any )) || { [[ -n $precmd ]] && ! { read -q '?Proceed? [y/N] ' } always { print } }; then
				break
			fi
		done
	} =(print -l $files) =(print -l $files)
	
}
function rmm() {
	if [[ $1 = -* ]]; then
		local options=$1
		shift
	else
		local options=
	fi
	print -l "rm $options${options:+ }-- "$^@ && { read -q "?Execute? " } always { print } && rm $options $@
}
alias mv='mv -i'
alias mv~='() { mv $1 $1~ }'
alias backup='() { cp $1 $1~ }'
alias asm='gcc -fno-stack-protector -fno-asynchronous-unwind-tables -S'
alias md='noglob md'
function md() { mkdir -p -- "$*" && cd -- "$*" }
alias mkln='() { mkdir -p -- "$(readlink $1)"; }'
alias cdln='() { cd "${$(readlink $1):h}"; }'
compdef '_files -g "*(@)"' cdln
alias ccd='() { (( $# > 0 )) && cd -- $1; while cd -- * 2>/dev/null; do :; done; }'
alias cp='cp -i'
alias cpm='() { cp -t ~m $@ }'
# alias cpp='cp --preserve --no-clobber'
alias pm='progress -M'
alias term='$TERMINAL >&- &disown'
alias fr='free -hwt'
alias gr='grep -i'
alias sl='ln -sf'
alias zcalc='() {
autoload -Uz zcalc{,-auto-insert}
zle -N zcalc-auto-insert
bindkey + zcalc-auto-insert
bindkey \\- zcalc-auto-insert
bindkey \* zcalc-auto-insert
bindkey / zcalc-auto-insert
ZCALC_AUTO_INSERT_PREFIX=ans
zcalc -f }'
alias cal='cal -m'
alias oct='od -tu1'
alias rm='rm -d -I --one-file-system'
alias rd='rmdir -pv'
alias rmdir='() {
	if (($# > 0)); then
		rmdir $@
	else
		local dirname=${PWD:t}
		cd -q -- ${PWD:h} &&
		if rmdir -- $dirname; then
			cd .
		else
			cd $dirname
		fi
	fi
}'
alias cpd='() { rsync -aihPv -- $^*/ }'
# alias p='pass letmein &>/dev/null'
alias iotop='sudo iotop'
alias fcf='() { print -z $(fc -nl 0 | fzf); }'
alias it='sudo iptables -xvL --line-numbers | sed '"'"'s/^Chain \(\S\+\)/Chain \x1b[1m\1\x1b[0m/'"'"
alias pl='pass login'
compdef '_files -W ~/.config/passwords' pl
alias bc='bc -lq'
alias a=aria2t
alias ffprobe='ffprobe -hide_banner'
alias ffmpeg='ffmpeg -hide_banner'
alias ffplay='ffplay -hide_banner'
alias ffplayq='ffplay -hide_banner -nodisp -autoexit -loglevel quiet'
function pdfmerge() {
	local out=a.pdf
	command gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -sOutputFile="$out" ${@:-*.pdf}
}
alias calcurse='calcurse -q'
# alias abook='abook --config ~/.config/abook/abookrc --datafile ~/.config/abook/addressbook'
alias curl='curl --remote-name-all'
alias co='curl -L'
alias oz='() { od -A x -t x1z -v $@ | sed '"'"'s/  >\(.*\)<$/  |\1|/'"'"' }'
alias du.='du --apparent-size -csh .'
alias du..='du --apparent-size -chd 1 .'
function sheep_pacman() {
	sheep pacman -Sy --noconfirm $* '&&' su $USER
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

function _check_user_files() {
	if ! find -H ~m -mindepth 1 -name '.*' -prune -o -empty -o -type f -print -quit | awk '{exit 1}'; then
		print -rP "%F{yellow}%Bwarning:%f%b ~m is not empty."
		tree -C ~m | less
	fi
	if pgrep -ax abduco &>/dev/null; then
		print -rP "%F{red}%Berror:%f%b abduco is running."
		return 1
	fi
	if pgrep -ax nvim &>/dev/null; then
		print -rP "%F{red}%Berror:%f%b nvim is running."
		return 1
	fi
	if pgrep -ax firefox &>/dev/null; then
		print -rP "%F{red}%Berror:%f%b firefox is running."
		return 1
	fi
	if ! { sync && sync }; then
		print -rP "%F{red}%Berror:%f%b sync failed."
		return 1
	fi
}

function _confirm_cmd() {
	print -rnP "%B%F{blue}::%f Confirm? [y/N]%b " &&
	read -sqr && command "${@}"
}
function poweroff() { _check_user_files && _confirm_cmd $0 "$@"; }
function reboot() { _check_user_files && _confirm_cmd $0 "$@"; }

function az() {
	exec ab
}

function ab() {
	if [[ -n "$1" ]] && ! which "$1" &>/dev/null; then
		local session="$1"
		shift
	else
		local session=$(tr </dev/urandom -dc a-z | head -c3)
	fi
	abduco -c "$session" "${@:-$SHELL}"
}

function bwsh() {
	bwrap \
		--unsetenv SHLVL \
		--ro-bind / / \
		--dev /dev \
		--proc /proc \
		--tmpfs /tmp \
		--bind "$(realpath ~m)" "$(realpath ~m)" \
		--bind "$(realpath ~/.local/share/nvim/undo)" "$(realpath ~/.local/share/nvim/undo)" \
		--bind "$(realpath $PWD)" "$(realpath $PWD)" \
		--tmpfs ~/.config/passwords \
		--unshare-{user,ipc,pid,uts,cgroup} \
		--hostname bubble \
		--die-with-parent \
		--as-pid-1 \
		--chdir $PWD \
		/$SHELL
}

function print_composekeys() {
	less "/usr/share/X11/locale/$(grep --max-count=1 "${LANG%.*}.UTF-8\$" /usr/share/X11/locale/locale.dir | cut -d/ -f1)/Compose"
}

function M() { [[ ! $PWD/ =~ ^${:-~m}/ ]] && cd -q -- ~m; bwsh; }

if [[ -n "$WAYLAND_DISPLAY" ]]; then
	alias copy='wl-copy --primary'
elif [[ -n "$DISPLAY" ]]; then
	alias copy='xclip -selection primary'
fi

function license() {
	case "$1"; in
	gpl3|)
		curl -Lo COPYING 'https://www.gnu.org/licenses/gpl-3.0.txt' ;;
	lgpl)
		curl -Lo COPYING 'https://www.gnu.org/licenses/gpl-3.0.txt' \
		      -o COPYING.LESSER 'https://www.gnu.org/licenses/lgpl-3.0.txt' ;;
	wtfpl)
		curl -Lo COPYING 'http://www.wtfpl.net/txt/copying' ;;
	*)
		echo >&2 "unknown license kind: $1" ;;
	esac
}
compdef '_values license gpl3 lgpl wtfpl' license

# Fuzzy cd repository OR ".".
function c() {
	local root
	local dir

	if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
		root="."
	fi

	dir=$(find -H "$root" -mindepth 1 -name '.*' -prune -o -xtype d -printf '%P\n' 2>/dev/null | fzf) &&
	cd -- "$~dir" &&
	ls -lh
}

function checksum() {
	local hash
	for hash in md5 sha1 sha256 sha224 sha384 sha512; do
		print -rP "%B%F{blue}::%f Checking ${hash}sum...%b"
		find -H -maxdepth 2 -iname ${hash}sum.txt -o -iname "*.${hash}" \
			-execdir ${hash}sum -c {} \;
	done | $PAGER
}

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

# Open file.

# It will print running program name and old library that was removed or replaced with newer content.
function pacbreak() {
	lsof +c 0 | grep -w DEL | awk '1 { print $1 ": " $NF }' | sort -u
}

function pacww() {
	expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort | tail -n ${1:-20}
	# pacman -Qie | awk -F'\\s+:\\s+' '"Name" == $1 { name=$2 } "Install Date" == $1 { "date -d\"" $2 "\" -u +%Y-%m-%d\\ %R" | getline date; printf "%-40s %s\n", name, date }' | sort -t' ' -k2 -r
}

function --() {
	echo -ne '\e[A\r'
	local bar=
	for (( i=1; i <= COLUMNS; i++ )) do
		bar+=━
	done
	printf '%s\n' $bar
}

# a1net() {
#		ssh router.lan "uci set firewall.@rule[13].enabled='${1:-1}' && uci commit && /etc/init.d/firewall reload"
# }


# zstyle ':mime:' mailcap ~/.mailcap
# zstyle ':mime:' disown true
# zstyle ':mime:' current-shell true
# zstyle :mime: mime-types ~/.config/mime.types  # /usr/local/etc/mime.types \
#			/etc/mime.types
# autoload -U zsh-mime-setup
# zsh-mime-setup

# if [ -n "$DISPLAY" ]; then
#		alias asdf='
#			xkbcomp -I$HOME/.config/xkb $HOME/.config/xkb/keymap/custom.xkb $DISPLAY &&
#			xcape -e "Hyper_L=space;Control_L=Escape;Caps_Lock=Escape"'
#		alias aoeu='setxkbmap hu && pkill xcape'
# fi
