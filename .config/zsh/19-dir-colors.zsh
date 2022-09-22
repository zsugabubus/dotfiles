readonly ZCACHE=~/.cache/zsh

# Cache LS_COLOR-like variables.
[[ ! -d $ZCACHE ]] && mkdir -p $ZCACHE

readonly dir_colors=$ZCACHE/dir_colors

if [[ ! ~/.dir_colors -ot $dir_colors ]]; then
	$ZDOTDIR/dir-colors.awk ~/.dir_colors >$dir_colors
	rm -f $dir_colors-*(N)
fi

local x
for x ('' .icons .colors); do
	if [[ ! -f $dir_colors-$TERM$x ]]; then
		TERM=$TERM$x dircolors -b $dir_colors >$dir_colors-$TERM$x 2>/dev/null
	fi
done

eval ${${$(<$dir_colors-$TERM)//empty}//export/#}
eval ${${${$(<$dir_colors-$TERM.icons)//LS_COLORS/LS_ICONS}//empty}//export/#}
alias ls-color="LS_COLORS=${(qq)LS_COLORS} command ls"

local TREE_COLORS=${LS_COLORS//\\e/$'\e'}

alias tree-color="TREE_COLORS=${(qq)TREE_COLORS} command tree"

eval ${${${$(<$ZCACHE/dir_colors-$TERM.colors)//LS_COLORS/local LS_COLORS_ONLY}//empty}//export/#}
