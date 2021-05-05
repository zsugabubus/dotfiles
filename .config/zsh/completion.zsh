# https://stackoverflow.com/questions/24836684/file-completion-priorities-in-zsh
zmodload zsh/complist &&
autoload -Uz compinit 2>/dev/null &&
# regenerate completion file at every startup
# -u: disable compaudit warning when using `bubblewrap`
compinit -u -d "$XDG_RUNTIME_DIR/zcompdump" || ( ${:?"Don't fuckin' move"} )

zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path ~/.cache/zcompcache
zstyle ':completion:*' rehash false

# Complete unambiguous part and show all possible matches.
setopt auto_list nolist_ambiguous
# Allow <Tab> completing menu.
setopt auto_menu
# Only second <Tab> completes menu.
setopt nomenu_complete
unsetopt list_types # Functionality is provided by `ls`.
setopt list_rows_first
setopt list_packed
# setopt always_to_end
setopt glob_complete
setopt extended_glob
setopt case_glob
setopt auto_remove_slash
setopt auto_param_keys
setopt complete_aliases
setopt complete_in_word

local dircolors_gen=$HOME/.cache/dir_colors
if [[ ! ~/.dir_colors -ot $dircolors_gen ]]; then
	awk -f ~/.config/zsh/dircolors.awk ~/.dir_colors >$dircolors_gen
fi

# See: ZSHCOMPWID(1) “COMPLETION MATCHING CONTROL”
zstyle ':completion::complete:*::' matcher-list \
	'' 'm:{a-zA-Z-_}={A-Za-z_-} l:|=* r:|[-.]=* r:|[-_./]|/=* r:|=*'

eval ${${$(env TERM=$TERM.icons dircolors -b $dircolors_gen)//LS_COLORS/LS_ICONS}//empty}

eval ${$(dircolors -b $dircolors_gen)//empty}
export TREE_COLORS=$(sed 's.\\e.\x1b.g' <<<$LS_COLORS)
# zstyle ':completion::complete:*' menu # no-select yes
zstyle ':completion::complete:*' verbose yes
zstyle ':completion::complete:*' file-sort modification reverse follow
# zstyle ':completion::complete:*' list-colors ${(s.:.)LS_COLORS}
# Place every tag in the same-named group.
zstyle ':completion::complete:*' group-name ''
zstyle ':completion::complete:*' list-colors ${(s.:.)$(eval ${$(env "TERM=$TERM.colors" dircolors -b $dircolors_gen)//empty}; <<<$LS_COLORS)}
# Complete files only once per line.
zstyle ':completion::complete:*:other-files' ignore-line other
zstyle ':completion::complete:*:directories' ignore-line other
# Show ignored matches as last resort.
zstyle ':completion::complete:*' single-ignored show
# Always perform completion on <Tab>.
zstyle ':completion::*' insert-tab false

# zstyle ':completion::complete:e:*' menu select
zstyle ':completion::complete:(mp|mpv):*' ignored-patterns '*.aria2' '(#i)**/*sample*' '*.(txt|nfo)'
zstyle ':completion::complete:e:*' ignored-patterns '*.(o|d|out)'

unset dircolors

zstyle ':completion::complete:*' list-dirs-first true
zstyle ':completion::complete:(cat|cp|rm|nvim):*' file-patterns \
	'%p(^-/):other-files:files %p(-/):directories:directories'

zstyle ':completion::complete:-tilde-::' group-order named-directories path-directories expand

zstyle ':completion::complete:-command-:*' file-patterns \
	'*(#q-*):executables:"exacutable file" *(-/):directories:directory'
# zstyle ':completion::complete:-command-:*' file-patterns \
#		'%p(^-/):globbed-files:globbed-files %p(-/):globbed-directories:globbed-directories'
zstyle ':completion::complete:-command-:*:functions' ignored-patterns '_*'
zstyle ':completion::complete:-command-::parameters' ignored-patterns '[A-Z]*'
zstyle ':completion::complete:-command-::' tag-order 'local-directories' 'users'
zstyle ':completion::complete:-command-::' group-order \
	executables directories local-directories suffix-aliases directory-stack path-directories builtins functions commands

# `cd`
zstyle ':completion::complete:cd::' ignore-parents parent pwd
zstyle ':completion::complete:cd::' tag-order 'local-directories' 'directory-stack path-directories named-directories' 'users'
zstyle ':completion::complete:cd::' group-order local-directories named-directories

# `man`
zstyle ':completion::complete:man:manuals' separate-sections true

# `kill`
zstyle ':completion::complete:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=1'
zstyle ':completion:*:processes'                command "ps -u $USER -o pid,state,command -w -w"

# `killall`
# zstyle ':completion::complete:killall:*' menu yes select
# zstyle ':completion::complete:killall:*' force-list always
# zstyle ':completion:*:processes-names' command "ps -u $USER --no-headers -o args,pid,state,command -w -w"
