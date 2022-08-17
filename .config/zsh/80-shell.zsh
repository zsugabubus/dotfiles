REPORTTIME=1
TIMEFMT='%J  %U user %S system %P cpu %*E total %MkB max %R faults'
DIRSTACKSIZE=10

function command_not_found_handler() {
	print -u2 -r "zsh: command not found: ${(q)1}.  This incident will be reported."
	return 127
}

local function auto-push() {
	(( __zfiles_active )) && return
	dirs -v
}
add-zsh-hook chpwd auto-push

local function auto-ls() {
	(( __zfiles_active )) && return
	# Auto-ls small directories only.
	local -A stat
	zstat -sNH stat -F '' -- . 2>/dev/null &&
	(( ${stat[size]} <= 4096 )) &&
	l
}
add-zsh-hook chpwd auto-ls

local function auto-git() {
	(( __zfiles_active )) && return
	test -d .git || return
	[[ $PWD == ~ ]] && return
	git zsh-status
}
add-zsh-hook chpwd auto-git
