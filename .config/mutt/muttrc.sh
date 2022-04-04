#!/bin/dash -e

# Options {{{
if test -n "$TMUX"; then
	echo 'set editor="$my_dotdir/bged" background_edit=yes'
else
	echo 'set editor="$EDITOR"'
fi
# }}}
# Mailboxes {{{
cd -- "$MAIL"

echo 'unmailboxes *'

echo 'set spoolfile=+'"$(readlink .spool)"

for maildir in */*/cur */cur; do
	maildir=${maildir%/cur}
	group=${maildir%/*}

	# Is grouped?
	if test -d "$group/inbox"; then
		# Indentation have to be manually crafted since Mutt's method works only
		# if we inserted a dummy x mailbox that is simply a waste of space. This
		# way heading line serves as the inbox.
		echo "mailboxes -label $group =$group/inbox"
		case $maildir in
		*/inbox) ;;
		*) echo "mailboxes -label '  ${maildir#*/}' =$maildir" ;;
		esac
	else
		echo "mailboxes =$maildir"
	fi

	muttrc=$group/muttrc
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
# }}}

# vim: ft=sh
