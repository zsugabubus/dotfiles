typeset -A ZSH_HIGHLIGHT_STYLES=(
  [unknown-token]='fg=235,bg=red'
  [alias]='bold'
  [comment]='fg=245'
  [command]='bold'
  [precommand]='fg=236,bold,underline'
  [globbing]='underline'
  [reserved-word]='fg=177,bold'
  [builtin]='fg=26'
  [dollar-double-quoted-argument]='fg=26,bg=255'
  [redirection]='bold,fg=206'
  [process-substitution-delimiter]='fg=205'
  [arg0]='fg=black,bold'
  [back-dollar-quoted-argument]='fg=234'
  [back-double-quoted-argument]='fg=234'
  [back-quoted-argument]='fg=53'
  [back-quoted-argument-unclosed]='fg=53'
  [back-quoted-argument-delimiter]='fg=53'
  [double-quoted-argument]='fg=64'
  [double-quoted-argument-unclosed]='fg=64'
  [dollar-quoted-argument]='fg=64'
  [dollar-quoted-argument-unclosed]='fg=64'
  [single-quoted-argument]='fg=65'
  [single-quoted-argument-unclosed]='fg=65'
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
    [single-hyphen-option]='fg=234'
    [double-hyphen-option]='fg=234'
  )
  ;;
esac

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'
FZF_DEFAULT_OPTS+=' --color=gutter:-1,pointer:214,hl+:238,hl:214,spinner:240'
ZSH_OPEN_TAGS_FOREGROUND='16'
# vim: fdm=marker
