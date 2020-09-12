# Setup color palette.
if [[ $TERM == linux ]]; then
	# See console_codes(4).
	echo -en '
\e%G
\e]P01c1c1c
\e]P1ec407a
\e]P28bc34a
\e]P3ffa726
\e]P42196f3
\e]P59575cd
\e]P600bcd4
\e]P7c4c4c4
\e]P8617d8a
\e]P9ec407a
\e]Pa9ccc65
\e]Pbffb74d
\e]Pc42a5f5
\e]Pdb39ddb
\e]Pe26c6da
\e]Pfffffff' | tr -d \\n
	setterm --blank 1 --powerdown 1 --powersave powerdown
fi

# Freeze terminal
# stty -ixon
ttyctl -f
