typeset -A ZSH_HIGHLIGHT_STYLES=(
  [unknown-token]='fg=235,bg=red'
  [alias]='bold'
  [comment]='fg=244'
  [command]='bold'
  [precommand]='fg=255,bold,underline'
  [globbing]='underline'
  [reserved-word]='fg=91,bold'
  [builtin]='fg=37'
  [dollar-double-quoted-argument]='fg=37'
  [redirection]='bold,fg=206'
  [process-substitution-delimiter]='fg=205'
  [arg0]='fg=white,bold'
  [back-dollar-quoted-argument]='fg=234'
  [back-double-quoted-argument]='fg=234'
  [back-quoted-argument]='fg=53'
  [back-quoted-argument-unclosed]='fg=53'
  [back-quoted-argument-delimiter]='fg=53'
  [double-quoted-argument]='fg=222'
  [double-quoted-argument-unclosed]='fg=222'
  [dollar-quoted-argument]='fg=222'
  [dollar-quoted-argument-unclosed]='fg=222'
  [single-quoted-argument]='fg=222'
  [single-quoted-argument-unclosed]='fg=222'
)

case "$TERM" in
linux)
  ZSH_HIGHLIGHT_STYLES+=(
    [single-hyphen-option]='fg=254'
    [double-hyphen-option]='fg=254'
  )
  ;;
*)
  ZSH_HIGHLIGHT_STYLES+=(
    [single-hyphen-option]='fg=253'
    [double-hyphen-option]='fg=253'
  )
  ;;
esac

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'
FZF_DEFAULT_OPTS+=' --color=gutter:-1,pointer:214,hl+:226,hl:226,spinner:240'
ZSH_OPEN_TAGS_FOREGROUND='231'
# vim: fdm=marker
