#!/bin/dash -e

if test "$PWD" = ~; then
	echo 'set attach_save_dir=`exec zsh -c ". \\$ZDOTDIR/??-hashes*.zsh; print ~m"`'
fi

if test -n "$TMUX"; then
	echo 'set editor="$my_dotdir/bged" background_edit=yes'
else
	echo 'set editor="$EDITOR"'
fi

cd -- "$MAIL"

echo 'unmailboxes *'

echo 'set spoolfile=+'"$(readlink .spool)"

# Indentation have to be manually crafted since Mutt's method works only
# if we inserted a dummy x mailbox that is simply a waste of space. This
# way heading line serves as the inbox.
for dir in */inbox */cur; do
	maildir=${dir%/*}

	case $dir in
	*/cur) echo "mailboxes =$maildir" ;;
	*) echo "mailboxes -label $maildir =$maildir/inbox" ;;
	esac

	for subdir in "$maildir/"*/; do
		subdir=${subdir%/}
		case $subdir in
		*/cur|*/new|*/tmp|*/inbox) ;;
		*) echo "mailboxes -label '  ${subdir#*/}' =$subdir" ;;
		esac
	done

	muttrc=$maildir/muttrc
	if test -f "$muttrc"; then
		echo "folder-hook $maildir 'source =$muttrc'"
	fi
done

for signature in */signature; do
	mgroup=${signature%/*}
	echo "folder-hook $mgroup 'set signature==$signature'"
done

for maildir in */cur */inbox; do
	maildir=${maildir%/cur}

	s=$maildir
	while {
		postfix=${s#?}
		key=${s%$postfix}
		case $key in
		'') false ;;
		[a-z]) eval test -n '"$KEY_'"$key"\" ;;
		esac
	}
	do
		s=$postfix
	done

	if test -n "$key"; then
		echo "macro index <space>$key \"<change-folder>=$maildir<return>\""
		eval KEY_$key=1
	fi
done
