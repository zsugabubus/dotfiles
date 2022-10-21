# https://stackoverflow.com/questions/24836684/file-completion-priorities-in-zsh
function zcompile_if_modified() {
	[[ $1.zwc -nt $1 ]] || zcompile $1
}
zmodload zsh/complist &&
autoload -Uz compinit 2>/dev/null &&
# regenerate completion file at every startup
# -u: disable compaudit warning when using `bubblewrap`
compinit -u -d ~/.cache/zcompdump
zcompile_if_modified ~/.cache/zcompdump

zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path ~/.cache/zcompcache
zstyle ':completion:*' rehash false

setopt auto_list nolist_ambiguous # Complete unambiguous part and show all possible matches.
setopt auto_menu # Allow <Tab> completing menu.
setopt auto_param_keys
setopt auto_remove_slash
setopt case_glob
setopt complete_aliases
setopt complete_in_word
setopt extended_glob
setopt glob_complete
setopt glob_star_short
setopt list_packed
setopt list_rows_first
setopt nomenu_complete # Only second <Tab> completes menu.
unsetopt list_types

zstyle ':completion::complete:*' verbose yes
zstyle ':completion::complete:*' file-sort modification reverse follow
# Place every tag in the same-named group.
zstyle ':completion::complete:*' group-name ''
zstyle ':completion::complete:*' list-colors ${(s.:.)LS_COLORS_ONLY}
# (1) Exact begin.
# (2) Smart-case begin.
# (3) X/Y X*/Y
# (4) --> Begin match anywhere.
# (5) *l*a*z*y*
zstyle ':completion::complete:*::' matcher-list \
	'' +'m:{[:lower:]-_}={[:upper:]_-} r:|[-_./]=*' +'l:|=* r:|?=**'

# Complete files only once per line.
zstyle ':completion::complete:*:other-files' ignore-line other
zstyle ':completion::complete:*:directories' ignore-line other
# Show ignored matches as last resort.
zstyle ':completion::complete:*' single-ignored show
# Always perform completion on <Tab>.
zstyle ':completion::*' insert-tab false

zstyle ':completion::complete:*' list-dirs-first true
zstyle ':completion::complete:(cat|cp|rm|nvim):*' file-patterns \
	'%p(^-/):other-files:files %p(-/):directories:directories'

zstyle ':completion::complete:-command-:*' file-patterns \
	'*(#q-*):executables:"exacutable file" *(-/):directories:directory'
zstyle ':completion::complete:-command-:*:functions' ignored-patterns '_*'
zstyle ':completion::complete:-command-::parameters' ignored-patterns '[A-Z]*'
zstyle ':completion::complete:-command-::' tag-order 'local-directories directories' '! users' '-'
zstyle ':completion::complete:-command-::' group-order \
	directories local-directories suffix-aliases directory-stack path-directories builtins functions

zstyle ':completion::complete:cd::' ignore-parents parent pwd
zstyle ':completion::complete:cd::' tag-order 'local-directories' '! users' '-'
zstyle ':completion::complete:cd::' group-order local-directories named-directories

zstyle ':completion::complete:-tilde-::' tag-order 'named-directories' '! users' '-'
zstyle ':completion::complete:-tilde-::' group-order named-directories path-directories expand

zstyle ':completion::complete:man:manuals' separate-sections true

zstyle ':completion::complete:*:processes' command "ps fo pid,stat,tname,start_time,pcpu,pmem,time,command -u $USER"
zstyle ':completion::complete:*:processes' list-colors '=(#b) #([0-9]#)*=0=1'
zstyle ':completion::complete:*:processes' sort false
zstyle ':completion::complete:*:processes' menu yes select

zstyle ':completion::complete:mpv:argument-rest:' group-order files directories
