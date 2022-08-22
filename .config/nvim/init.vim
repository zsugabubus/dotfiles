" nvim -u NONE --cmd 'profile start profile|profile file *|source ~/.config/nvim/init.vim|profile stop'

" :so $VIMRUNTIME/syntax/hitest.vim

if !has('nvim') || filewritable(stdpath('config').'/init.vim')
	command! -nargs=+ IfLocal <args>
	command! -nargs=+ IfSandbox
else
	command! -nargs=+ IfLocal
	command! -nargs=+ IfSandbox <args>
endif

" PackCommand {pack} {cmd}...
" Auto packadd {pack} on first {cmd} invocation.
function s:pack_command(pack, ...)
	let delcommands = copy(a:000)->map({_,cmd-> 'delcommand '.cmd.'|'})->join()
	for cmd in a:000
		execute printf('silent! command -bang -nargs=* %s %spackadd %s|<mods> %s<bang> <args>',
			\ cmd, delcommands, a:pack, cmd)
	endfor
endfunction
command! -nargs=* PackCommand call s:pack_command(<f-args>)

IfLocal command! PackUpdate execute 'terminal' printf('find %s -mindepth 3 -maxdepth 3 -type d -exec printf \%%s:\\n {} \; -execdir git -C {} pull \;', shellescape(stdpath('data').'/site/pack'))

" Create a command abbrevation.
command! -nargs=+ Ccabbrev let s:_ = [<f-args>][0]|execute(printf("cnoreabbrev <expr> %s getcmdtype() ==# ':' && getcmdpos() ==# %d ? %s : %s", s:_, len(s:_) + 1, <q-args>[len(s:_) + 1:], string(s:_)))

" Get rid of bloat.
let loaded_tutor_mode_plugin = 1

set shortmess+=mrFI
set nowrap
setglobal ts=8 sw=0 sts=0 noet
set foldopen=
set spelllang=en
set ignorecase fileignorecase wildignorecase smartcase
set scrolloff=5 sidescrolloff=23
set nrformats-=octal
set splitright
set cinoptions+=t0,:0,l1
set lazyredraw
set matchpairs+=‘:’,“:”
set timeoutlen=600
set noswapfile
set autowrite
set hidden
set switchbuf=useopen
set path+=src/**,include/**
augroup vimrc_autopath
	autocmd! VimEnter,DirChanged *
		\ if isdirectory('node_modules')|
		\   set path-=**|
		\ else|
		\   set path+=**|
		\ endif
augroup END
set wildcharm=<C-Z>
set autoindent
set copyindent
set wildmenu
set wildmode=list:longest,full
set wildignore+=*.a,*.d,*.o,*.out,*.dll
set wildignore+=.git
set wildignore+=*.lock,*~,check/**,node_modules
" Rank files lower with no suffix.
set suffixes+=,
set grepprg=noglob\ rg\ --vimgrep\ --smart-case
set grepformat=%f:%l:%c:%m
set diffopt=filler,vertical,algorithm:patience
set nomore
set foldtext=VimFoldText()
set nojoinspaces " no double space
set completeopt=menu,longest,noselect,preview " XXX: How autocomplete with last?
" Shadon't
IfSandbox set shada="NONE" noundofile nowritebackup
IfLocal set undofile undodir=$HOME/.cache/nvim/undo
set list
set showbreak=\\
if $TERM ==# 'linux'
	set listchars=eol:$,tab:>\ ,trail:+,extends::,precedes::,nbsp:_
else
	" 24-bit colors. Yuhhuuu.
	set termguicolors
	set listchars=eol:$,tab:│\ ,trail:•,extends:⟩,precedes:⟨,space:·,nbsp:␣
	set listchars=eol:$,tab:›\ ,trail:•,extends:⟩,precedes:⟨,space:·,nbsp:␣
	if !has('nvim')
		let &t_8f = "\<Esc>[38:2:%lu:%lu:%lum"
		let &t_8b = "\<Esc>[48:2:%lu:%lu:%lum"
	endif
end

set title

set cursorline cursorlineopt=number
set number relativenumber
augroup vimrc_numbertoggle
	autocmd!
	autocmd FocusGained,InsertLeave,WinEnter * ++nested
		\ if &number && &buftype ==# '' && !&diff && &filetype !=# 'qf'|
		\   setlocal relativenumber|
		\ endif
	autocmd FocusLost,InsertEnter,WinLeave * ++nested
		\ if &number && &buftype ==# '' && !&diff && &filetype !=# 'qf'|
		\   setlocal norelativenumber|
		\ endif
	autocmd!
augroup END

function! VimFoldText() abort
	let right = ' ('.string(v:foldend - v:foldstart + 1).' )'
	let line = getline(nextnonblank(v:foldstart))
	let text = substitute(line, '\v^.{-}<(\w.{-})\s*%(\{\{\{.*)?$', '\1', '')
	let tw = min([(&tw > 0 ? &tw : 80), winwidth('%') - float2nr(ceil(log10(line('$')))) - 1])
	let left = repeat(' ', strdisplaywidth(matchstr(line, '\m^\s*')))
	let text = text.repeat(' ', tw - strdisplaywidth(left.text.right))
	return left.text.right.repeat(' ', 999)
endfunction

cnoremap <C-p> <Up>
cnoremap <C-n> <Down>
cnoremap <M-b> <C-Left>
cnoremap <M-f> <C-Right>
cnoremap <C-b> <Left>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>

inoremap <C-a> <C-o>_
inoremap <C-e> <C-o>g_<Right>

inoremap <expr> <C-s> strftime("%F")
inoremap <expr> <C-f> expand("%:t:r")

nnoremap <silent> g<C-o> :set paste!<CR>

" How many times... you little shit...
nnoremap U <nop>

" replace f/F and t/T to jump only to the beginning of snake_case or
" PascalCase words if pattern is lowercase; otherwise normal f/F and t/T that
" does not stop at end-of-line
function! s:magic_char_search(mode, forward) abort
	let cs = getcharsearch()
	let isvisual = a:mode =~# "\\m\\C^[vV\<C-V>]$"
	let escchar = escape(cs.char, '\')
	let lnum = line('.')
	let e = (-!!cs.until + (a:mode ==# 'n' ? 0 : isvisual ? &selection !=# 'inclusive' : 1)) * (cs.forward ==# a:forward ? 1 : -1) " where to positionate cursor
	let pattern = (cs.char =~# '\m\l'
		\ ? '\v\C%(%('.(e ==# -1 ? '\ze\_.' : '').'<|'.(e ==# -1 ? '\ze' : '').'[_0-9])\V\['.tolower(escchar).toupper(escchar).']'
			\ .'\v|'.(e ==# -1 ? '\ze' : '').'[a-z_]\V'.toupper(escchar)
			\ .'\v|\V'.toupper(escchar).'\v[a-z]@=)'
		\ : '\c'.(e ==# -1 ? '\ze\_.' : '').'\V'.escchar).(e ==# 1 ? '\_.\ze' : '')
	let flags = 'eW'.(cs.forward ==# a:forward ? 'z' : 'b')
	if isvisual
		normal! gv
	endif

	" Hmmm. Maybe we could use normal! /search/e... simply; but it works so do
	" not fucking touch it.
	for nth in range(1, v:count1)
		call search(pattern, flags)
	endfor
endfunction

for s:letter in [',', ';']
	execute printf("nnoremap <silent> %s :call <SID>magic_char_search('n', %d)<CR>",
		\ s:letter, s:letter ==# ';')
endfor
for s:letter in ['f', 'F', 't', 'T']
	for s:map in ['n', 'x', 'o']
		execute printf("%snoremap <expr><silent> %s [setcharsearch({'forward': %d, 'until': %d, 'char': getcharstr()}), ':<C-U>call <SID>magic_char_search(\"'.mode(1).'\", 1)\<CR>'][1]",
			\ s:map, s:letter, s:letter =~# '\l', s:letter =~? 't')
		" execute printf(\"%snoremap <expr><silent> %s '<Cmd>keeppattern /'.getcharstr().'\<CR>'\",
			" \ s:map, s:letter)
	endfor
endfor
unlet s:letter s:map

augroup vimrc_insertempty
	autocmd!
	autocmd InsertLeave *
		\ try|
		\   if empty(trim(getline('.')))|
		\     undojoin|
		\     call setline('.', '')|
		\   endif|
		\ catch /undojoin/|
		\ endtry
augroup END

if !has('nvim')
	autocmd ShellCmdPost * redraw
endif

function! s:publish(bang, mods, args) abort
	let prog =<< AWK
function cp(file) { print file | "xargs -r -P2 -I{} install -Dvpm 664 {} " public_site "{}" }
function rm(file) { print public_site file | "xargs -r rm -v" }
"D" == $1 { rm($2) }
$1 ~ /^R/ { rm($2); cp($3) }
$1 ~ /^[AM]/ { cp($2) }
AWK

	let public_site = fnamemodify(Git().wd, ':.').'.public_site'
	if getftype(public_site) !=# 'link'
		echohl Error
		echomsg printf('Missing or invalid %s', public_site)
		echohl None
		return
	endif
	let public_site .= '/'

	execute '!'.
	\ (a:bang
	\    ? 'printf "M\t\%s\\n" '.join(map(flatten(map(a:args, {_,arg-> glob(arg, 1, 1)})), {_,file-> shellescape(file)}), ' ')
	\    : 'git diff --name-status '.(empty(a:args) ? '@' : join(a:args, ' ')))
	\ .(a:mods =~# 'verbose' ? '' : ' | awk -vFS="\t" -vpublic_site='.shellescape(public_site).' '.shellescape(join(prog, "\n"), 1))
	if !has('nvim')
		redraw!
	endif
	if !v:shell_error
		if a:mods !~# 'verbose'
			call feedkeys("\<CR>", "nt")
			redraw
			echomsg 'Upload succeed'
		endif
	else
		echohl Error
		echomsg 'Upload failed'
		echohl None

	endif
endfunction

command! -nargs=* -bang Publish call s:publish(<bang>0, <q-mods>, [<f-args>])
nnoremap <silent> <M-p> :update<bar>Publish! %<CR>

nnoremap Q :normal n.<CR>zz

" Reindent inner % lines.
nmap >i >%<<$%<<$%
nmap <i <%>>$%>>$%

" Delete surrounding lines.
nmap d< $<%%dd<C-O>dd

inoremap <C-r> <C-r><C-o>

" kO -- Only useful if you have reached the line with a motion.
nnoremap <expr> a "aO"[prevnonblank(line('.')) ==# line('.') - 1 && prevnonblank(line('.') + 1) ==# line('.') + 1]
" Reindent before append.
nnoremap <expr> A !empty(getline('.')) ? 'A' : 'cc'

inoremap <expr> <C-j> line('.') ==# line('$') ? "\<C-O>o" : "\<Down>\<End>"

nnoremap d_ "_dd

" Delete argument from list.
nnoremap <silent> dar :.argdelete<bar>argument<CR>

" m but show available marks.
nnoremap <expr> m ':echomsg "'.join(map(map(range(char2nr('a'), char2nr('z')) + range(char2nr('A'), char2nr('Z')), {_,nr-> nr2char(nr)}), {_,mark-> (getpos("'".mark)[1] ==# 0 ? mark : ' ')}), '').'"<CR>m'

" Text objects {{{1
" Jump to parent indention.
nnoremap <silent> <expr> <C-q> '?\v^\s+\zs%<'.indent(prevnonblank('.')).'v\S\|^#@!\S?s-1<CR>
	\ :noh\|call histdel("search", -1)\|let @/ = histget("search", -1)<CR>'

" Parameter text object.
onoremap <silent> i, :<C-U>execute "keeppattern normal! v?\\m[(,]?;/\\S/\<lt>CR>o/\\m[,)]/s-1\<lt>CR>"<CR>
" onoremap <silent> a, :<C-U>execute \"keeppattern normal! v/\\v,\\s*\\zs|\\zs)\<lt>CR>\"<CR>

" Inner line text object.
xnoremap il <Esc>_vg_
xnoremap al <Esc>0v$h
omap <silent> il :<C-U>normal vil<CR>
omap <silent> al :<C-U>normal val<CR>

" Statement text object.
onoremap <silent> i; :<C-U>execute "keeppattern normal! 0v/;/$\<lt>CR>"<CR>
onoremap <silent> a; :<C-U>execute "keeppattern normal! 0v/;/;/\\m^\s*/$\<lt>CR>"<CR>

" Backticks text object.
onoremap <silent> i` :<C-U>execute "keeppattern normal! v?\\v`\\_.{-}%#<bar>%#`?s+1\<lt>CR>o/`/e-1\<lt>CR>"<CR>
onoremap <silent> a` :<C-U>execute "keeppattern normal! v?\\v`\\_.{-}%#<bar>%#`\<lt>CR>o/\\m`\\s*/e\<lt>CR>"<CR>

" Indentation text object.
" Ok. Do not fucking touch it.
vnoremap <silent> ii :<C-U>execute "keeppattern normal! ". '?\v^\s+\zs%<'.indent(prevnonblank('.')).'v\S\|^#@!\S?+1;' ."/\\v\\s\\S\<lt>CR>V/\\v^(\\s+)\\S.*%(\\n<bar>\\1.*)*/e\<lt>CR>"<CR>
omap <silent> ii :<C-U>normal vii<CR>

" Function text object.
vnoremap <silent> af :<C-U>execute "keeppattern normal! }[[{jV]]%}"<CR>
omap <silent> af :<C-U>normal vaf<CR>

" Make {, } linewise.
onoremap <silent> { V{
onoremap <silent> } V}
" 1}}}

command! -nargs=1 RegEdit let @<args>=input('"'.<q-args>.'=', @<args>)

" Christmas bells.
command! Bell call writefile(["\x07"], '/dev/tty', 'b')

function! s:errorformat_make() abort
	if 'make' == &makeprg|
		set errorformat^=make:\ %*[[]%f:%l:\ %m
		set errorformat^=make%.%#:\ ***\ %*[[]%f:%l:\ %.%#]\ Error\ %n
		set errorformat^=make%.%#:\ ***\ %*[[]%f:%l:\ %m
		set errorformat^=/usr/bin/ld:\ %f:%l:\ %m
	endif
endfunction

augroup vimrc_errorformat
	autocmd!
	autocmd VimEnter * call s:errorformat_make()
	autocmd OptionSet makeprg call s:errorformat_make()
augroup END

function! s:makeprg_magic() abort
	if !empty(&l:makeprg)
		return
	endif

	if filereadable('Makefile')
		setlocal makeprg=make
	elseif filereadable('meson.build')
		setlocal makeprg=meson\ compile\ -C\ build
	elseif filereadable('go.mod')
		compiler go
	elseif filereadable(get(Git(), 'wd', '').'Cargo.toml')
		compiler cargo
	elseif filereadable('package.json')
		setlocal makeprg=npm\ run\ build
	endif
endfunction

function! s:make() abort
	let start = strftime('%s')
	echon "\U1f6a7  Building...  \U1f6a7"
	call s:makeprg_magic()
	if 0 <=# stridx(&l:makeprg, '$*')
		make build
	else
		make
	endif
	Bell
	redraw
	let errors = 0
	let warnings = 0
	for item in getqflist()
		if item.text =~? ' error:\? ' || item.type ==# 'E'
			let errors += 1
		elseif item.text =~? ' warning:\? ' || item.type ==# 'W'
			let warnings += 1
		endif
	endfor

	let elapsed = strftime('%s') - start
	echon printf("[%2d:%02ds] ", elapsed / 60, elapsed % 60)
	if 0 <# errors
		echon "\u274c Build failed: "
		echohl Error
		echon errors " errors"
		echohl None
		if 0 <# warnings
			echon ", "
			echohl WarningMsg
			echon warnings " warnings"
			echohl None
		endif
	elseif 0 <# warnings
		echon "\U1f64c Build finished: "
		echohl WarningMsg
		echon warnings " warnings"
		echohl None
	else
		echon "\U1f64f Build finished"
		call feedkeys("\<CR>", "nt")
		cclose
	endif
endfunction

command! Ctags !test -d build && ln -sf build/tags tags; ctags -R --exclude=node_modules --exclude='*.json' --exclude='*.patch' '--map-typescript=+.tsx'

nnoremap <silent> <M-m> :call <SID>make()<CR>
nnoremap <silent> <M-r> :call <SID>make()<CR>:if !v:shell_error<bar>execute 'tabnew<bar>terminal make run'<bar>endif<CR>

nnoremap <silent> <M-l> :lnext<CR>:silent! normal! zOzz<CR>
nnoremap <silent> <M-L> :lprev<CR>:silent! normal! zOzz<CR>
nnoremap <silent> <M-n> :cnext<CR>:silent! normal! zOzz<CR>
nnoremap <silent> <M-N> :cprev<CR>:silent! normal! zOzz<CR>
nnoremap <silent> <M-f> :next<CR>
nnoremap <silent> <M-F> :prev<CR>
nnoremap <silent> <M-w> :Bufdo if bufname() !=# ''<bar>update<bar>endif<CR>
nnoremap <silent> <M-q> :quit<CR>

" put the first line of the paragraph at the top of the window
" <C-E> does not want to get executed without execute... but <C-O> does... WTF!?
nnoremap <silent><expr> z{ ':set scrolloff=0<bar>:execute "keepjumps normal! {zt\<lt>C-O>\<lt>C-E>"<bar>:set scrolloff='.&scrolloff.'<CR>'

nnoremap <silent> gss :setlocal spell!<CR>
nnoremap <silent> gse :setlocal spell spelllang=en<CR>
nnoremap <silent> gsh :setlocal spell spelllang=hu<CR>

nnoremap <expr> <M-!> ':edit '.fnameescape(expand('%:h')).'/<C-z>'
nnoremap <expr> <M-t> ':tabedit '.fnameescape(expand('%:h')).'/<C-z>'
nnoremap <silent> <M-o> :buffer #<CR>

" Handy yanking to system-clipboard.
map gy "+yy

" Repeat last action over visual block.
xnoremap . :normal! .<CR>

" Execute macro over visual range
xnoremap <expr><silent> @ printf(':normal! @%s<CR>', getcharstr())

command! Bg let &background = 'light' == &background ? 'dark' : 'light'

" Perform glob on every lines.
command! -nargs=* -range Glob silent! execute ':<line1>,<line2>!while read; do print -l $REPLY/'.escape(<q-args>, '!%').'(N) $REPLY'.escape(<q-args>, '!%').'(N); done'

" Do command on every buffer and return to current.
command! -bang -nargs=+ Bufdo tabnew|execute 'bufdo<bang>' <q-args>|bdelete

" Sweep out untouched buffers.
command! Sweep call s:sweep()
function! s:sweep() abort
	for i in range(1,bufnr('$'))
		if bufexists(i) && !getbufvar(i, '&modified')
			execute i.'bdelete'
		endif
	endfor
endfunction

" Collect TODO items.
command! TODO GREP \b(TODO|FIXME|BUG|WTF)\b.*:

command! SynShow echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')

command! StripTrailingWhite keepjumps keeppatterns lockmarks silent %s/\m\s\+$//e

" Highlight illegal whitespace. (Red on white.)
augroup vimrc_japan
	autocmd!
	autocmd ColorScheme * highlight ExtraWhitespace ctermbg=197 ctermfg=231 guibg=#ff005f guifg=#ffffff
	highlight ExtraWhitespace ctermbg=197 ctermfg=231 guibg=#ff005f guifg=#ffffff
	autocmd FileType,BufWinEnter,WinNew *
		\ if has_key(w:, 'japan')|
		\   call matchdelete(w:japan)|
		\   unlet w:japan|
		\ endif|
		\ if &buftype ==# '' && !&readonly && &modifiable && &filetype !~# '\v^(|text|markdown|mail)$|git|diff|log' |
		\   let w:japan = matchadd('ExtraWhitespace', '\v +\t+|\s+%#@!$', 10)|
		\ endif
augroup END

Ccabbrev man 'Man'
command! -bar -bang -nargs=+ ManKeyword
	\ silent execute 'Man '.join([<f-args>][:-2], ' ')|
	\ call search('^\v {3,}\zs<\V'.escape([<f-args>][-1], '\').'\>', 'w')

augroup vimrc_autodiffupdate
	autocmd! TextChanged *
		\ if empty(&buftype)|
		\   diffupdate|
		\ endif
augroup END

" Quit from every diffed window; though quit is forbidden inside windo.
augroup vimrc_diffquit
	autocmd! QuitPre *
		\ if &diff|
		\   execute 'windo if winnr() !=# '.winnr().' && &diff|quit|endif'|
		\ endif
augroup END

augroup vimrc_autodiffoff
	autocmd!
	autocmd BufHidden *
		\ if !&buflisted|
		\   diffoff!|
		\ endif
	autocmd BufUnload *
		\ if &diff|
		\   diffoff!|
		\ endif
augroup END

command! -nargs=? Diff call s:diff(<q-args>)
function! s:diff(spec) abort
	let ft = &ft

	vertical new

	setlocal bufhidden=wipe buftype=nofile nobuflisted noswapfile
	let l:filetype = ft
	if !len(a:spec)
		let cmd = '++edit #'
		let name = fnameescape(expand('#').'.orig')
	elseif len(a:spec) ==# 1 && filereadable(a:spec[0])
		let name = a:spec[0]
		let cmd = '++edit '.name
	else
		let cmd = '!git show '.shellescape(a:spec, 1).':#'
		let name = fnameescape(a:spec).':'.fnameescape(expand('#'))
	endif

	silent execute 'read' cmd
	silent execute 'keepalt file' name
	silent 1delete _
	setlocal readonly
	diffthis
	nnoremap <silent><buffer> q :close<CR>

	wincmd p
	diffthis
endfunction

nnoremap <expr> + (!&diff ? 'g+' : ":diffput\<CR>")
nnoremap <expr> - (!&diff ? 'g-' : ":diffget\<CR>")

nnoremap <expr> dL (!&diff ? 'dL' : ":diffget LOCAL\<CR>")
nnoremap <expr> dB (!&diff ? 'dB' : ":diffget BASE\<CR>")
nnoremap <expr> dR (!&diff ? 'dR' : ":diffget REMOTE\<CR>")

augroup vimrc_skeletons
	autocmd! BufNewFile * autocmd FileType <buffer> ++once
		\ if changenr() == 0|
		\   call setline(1, get({
		\     'html': ['<!DOCTYPE html>', '<html>', '<head>', '<meta charset=UTF-8>', '<title></title>', '</head>', '<body>', '</body>', '</html>'],
		\     'php': ['<?php'],
		\     'sh': ['#!/bin/sh', ''],
		\     'zsh': ['#!/bin/zsh', ''],
		\     'bash': ['#!/bin/bash', ''],
		\     'python': ['#!/usr/bin/env python3', ''],
		\   }, &filetype, []))|
		\ endif|
		\ normal! G
augroup END

augroup vimrc_filetypes
	autocmd!
	autocmd FileType man
		\ for s:bookmark in split('sSYNOPSIS i#include dDESCRIPTION r^RETURN<bar>^EXIT eERRORS xEXAMPLES eSEE', ' ')|
		\   execute "nnoremap <silent><buffer><nowait> g".s:bookmark[0]." :call cursor(1, 1)<bar>call search('\\v".s:bookmark[1:]."', 'W')<bar>normal! zt<CR>"|
		\ endfor|
		\ nnoremap <buffer> <space> <C-D>|
		\ nnoremap <silent><buffer><nowait> ] :<C-U>call search('\v^[A-Z0-9]*\(\d', 'W')<CR>zt|
		\ nnoremap <silent><buffer><nowait> [ :<C-U>call search('\v^[A-Z0-9]*\(\d', 'Wb')<CR>zt|
		\ nnoremap <buffer> /<space><space> /^ \+

	autocmd FileType vim
		\ command! -range Execute execute substitute(join(getline(<line1>, <line2>), "\n"), '\m\n\s*\', '', 'g')

	autocmd FileType remind
		\ setlocal keywordprg=:ManKeyword\ 1\ remind

	autocmd FileType mbsyncrc
		\ setlocal keywordprg=:ManKeyword\ 1\ mbsync

	autocmd FileType tmux
		\ setlocal keywordprg=:ManKeyword\ 1\ tmux|
		\ setlocal iskeyword+=-

	autocmd FileType muttrc
		\ setlocal keywordprg=:ManKeyword\ 5\ muttrc

	autocmd FileType zsh
		\ setlocal keywordprg=:ManKeyword\ 1\ zshall

	autocmd BufRead zathurarc
		\ setlocal ft=cfg keywordprg=:ManKeyword\ 5\ zathurarc

	autocmd FileType diff
		\ nnoremap <expr> dd '-' == getline('.')[0] ? '0r ' : 'dd'

	autocmd FileType xml,html
		\ setlocal equalprg=xmllint\ --encode\ UTF-8\ --html\ --nowrap\ --dropdtd\ --format\ -

	autocmd FileType sh,zsh,dash
		\ setlocal ts=2|
		\ xnoremap <buffer> s< c<<EOF<CR><C-r><C-o>"EOF<CR><Esc><<gvo$B<Esc>i|
		\ nnoremap <silent><buffer><nowait> ]] :call search('^.*\(function\<bar>()\s*{\)', 'W')<CR>|
		\ nnoremap <silent><buffer><nowait> [[ :call search('^.*\(function\<bar>()\s*{\)', 'Wb')<CR>

	let php_sql_query = 1
	let php_htmlInStrings = 1
	let php_parent_error_close = 1
	autocmd FileType php
		\ set makeprg=php\ -lq\ %|
		\ set errorformat=%m\ in\ %f\ on\ line\ %l,%-GErrors\ parsing\ %f,%-G

	autocmd FileType plaintex,tex
		\ xnoremap <buffer> sli c\lstinline{<C-r><C-o>"}<Esc>|
		\ xnoremap <buffer> sq c\textquote{<C-r><C-o>"}<Esc>

	autocmd FileType vim,lua,yaml,css,stylus,xml,php,html,pug,gdb,vue,meson,*script*
		\ setlocal ts=2 sw=0

	autocmd FileType awk,cshtml
		\ setlocal ts=4 sw=0

	let c_gnu = 1
	let c_no_curly_error = 1 " (struct s){ } <-- avoid red
	autocmd FileType c,cpp
		\ setlocal ts=8 fdm=manual

	autocmd FileType rust
		\ setlocal ts=4 sw=4 fdm=manual

	autocmd FileType json,javascript
		\ setlocal ts=2 suffixesadd+=.js

	autocmd FileType lua
		\ setlocal ts=2 suffixesadd+=.lua

	autocmd FileType gitcommit
		\ command! -buffer WTC call setline(1, systemlist(['curl', '-s', 'http://whatthecommit.com/index.txt'])[0])|
		\ syntax match Normal ":bug:" conceal cchar=🐛

	autocmd FileType json
		\ setlocal equalprg=jq

	autocmd FileType xml
		\ setlocal equalprg=xmllint\ --encode\ UTF-8\ --format\ -

	autocmd FileType c,cpp
		\ setlocal equalprg=clang-format

	autocmd FileType gitcommit,markdown
		\ setlocal spell expandtab ts=2

	autocmd FileType mail
		\ setlocal wrap ts=4 et spell|
		\ execute 'normal' '}'|
		\ nnoremap <buffer> Q :x<CR>|
		\ nnoremap <buffer> <silent> gs gg/\C^Subject: \?\zs<CR>:noh<CR>vg_<C-G>|
		\ nnoremap <buffer> <silent> gb gg}

	let netrw_banner = 0
	let netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+'
	" let netrw_keepdir = 0
	autocmd FileType netrw
		\ nmap <buffer> . -|
		\ nmap <buffer> e :e<Space>
augroup END

augroup vimrc_reload
	autocmd! BufWritePost *colors/*.vim ++nested let &background=&background
	autocmd! BufWritePost init.vim,vimrc ++nested source <afile>
augroup END

augroup vimrc_autopackadd
	autocmd!
	IfLocal autocmd BufReadPre *.styl ++once packadd vim-stylus
	IfLocal autocmd BufReadPre *.pug  ++once packadd vim-pug
	IfLocal autocmd BufReadPre *.toml ++once packadd vim-toml
	IfLocal autocmd BufReadPre *.glsl ++once packadd vim-glsl
	IfLocal autocmd BufReadPre *.zig ++once packadd zig.vim
	IfLocal autocmd BufReadPre *.rs ++once packadd rust.vim
	" IfLocal autocmd FileType mail ++nested packadd vim-completecontacts
augroup END

IfLocal packadd vim-gnupg

" Automatically open quickfix and location window and make it modifiable.
augroup vimrc_quickfixfix
	autocmd!
	" autocmd QuickFixCmdPost [^l]* if index(map(range(1, winnr('$')), 'getbufvar(v:val, \"&buftype\")'), 'quickfix') ==# -1|silent! botright cwindow|echo \"opening\"|endif
	autocmd QuickFixCmdPost [^l]* ++nested
		\ if !empty(getqflist())|
		\   botright copen|
		\   silent! cfirst
		\   copen|
		\   call search('error:')|
		\   execute 'normal!' "\<CR>"|
		\   cc|
		\ else|
		\   silent! cclose|
		\ endif
	autocmd FileType qf setlocal modifiable nolist|
		\ nnoremap <expr><silent><buffer> dd ":<C-u>call setqflist(filter(getqflist(), 'v:key!=".(line('.') - 1)."'))<CR>:.".(line('.') - 1)."<CR>"|
		\ nnoremap <silent><buffer> df :<C-u>call setqflist(filter(getqflist(), 'v:val.bufnr!='.getqflist()[line('.') - 1].bufnr))<CR>|
		\ nnoremap <expr><silent><buffer> J ":pedit +".(getqflist()[line('.') - 1].lnum)." ".fnameescape(bufname(getqflist()[line('.') - 1].bufnr)).'<CR>j'|
		\ nnoremap <silent><buffer> <C-o> :colder<CR>|
		\ nnoremap <silent><buffer> <C-i> :cnewer<CR>
	autocmd QuickFixCmdPost l* ++nested silent! botright lwindow | setlocal modifiable
	" close non-essential windows on quit
	autocmd QuitPre          * ++nested silent! lclose | silent! cclose
augroup END

" autocmd BufLeave * if &buftype ==# 'quickfix' | echo 'leaving qf' | endif
Ccabbrev f 'find'.(' ' !=# v:char ? ' ' : '')

function! g:Acd()
	return haslocaldir() ? 'lcd' : haslocaldir(-1) ? 'tcd' : 'cd'
endfunction

Ccabbrev cd Acd()
Ccabbrev ccd Acd().' %:p:h'

" grep helper: search quoted text (can include spaces) when contains
" no -args.
command! -nargs=* GREP execute 'grep ' substitute(<q-args> =~ '\v^''|%(^|\s)-\w' ? <q-args> : shellescape(<q-args>, 1), '<bar>', '\\<bar>', 'g')|redraw
xnoremap // y:GREP -F '<C-r>=@"<CR>'<CR>
Ccabbrev gr 'GREP'

nmap <silent> z/ <Plug>(FuzzySearchFizzy)

Ccabbrev . '@:'

let pets_joker = ''
cnoremap <expr> <C-z> getcmdtype() == ':' ? '<C-f>A<C-x><C-v>' : '<C-f>A<C-n>'

xnoremap <expr> O (line('v') !=# line('.') ? line('v') < line('.') : col('v') < col('.')) ? '' : 'o'

nmap <silent> ds %%v%O<Esc>xgv<Left>o<Esc>xgvo<Esc>
xnoremap <silent><expr> s" mode() ==# 'V' ? 'c"""<CR><C-r><C-o>""""<Esc>' : 'c"<C-r><C-o>""<Esc>'
xnoremap <silent><expr> s' mode() ==# 'V' ? 'c''''''<CR><C-r><C-o>"''''''<Esc>' : 'c''<C-r><C-o>"''<Esc>'
xnoremap <silent><expr> s` mode() ==# 'V' ? 'c```<CR><C-r><C-o>"```<Esc>' : 'c`<C-r><C-o>"`<Esc>'
xnoremap <silent><expr> s> mode() ==# 'V' ? 'c<<CR><C-r><C-o>"><Esc>' : 'c<<C-r><C-o>"><Esc>'
xnoremap <silent><expr> s< substitute('c<%><C-r><C-o>"</%><Esc>', '%', input('<'), 'g')
xnoremap <silent><expr> sc substitute('c%<C-r><C-o>"%<Esc>', '%', getcharstr(), 'g')
xmap s<bar> sc<bar>
xmap s<CR> sc<CR>
for [s:left, s:right] in [['(', ')'], ['[', ']'], ['{', '}']]
	execute "xnoremap <silent> <expr> s".s:right." mode() ==# 'V' ? 'c".s:left."<CR><C-r><C-o>\"".s:right."<Esc>' : 'c".s:left."<C-r><C-o>\"".s:right."<Esc>'"
	execute "xnoremap <silent> <expr> s".s:left."  mode() ==# 'V' ? 'c".s:left."<CR><C-r><C-o>\"".s:right."<Esc>' : line('.') ==# line('v') ? 'c".s:left." <C-r><C-o>\" ".s:right."<Esc>' : 'c".s:left."<C-r><C-o>\"".s:right."<Esc>'"
endfor
unlet s:left s:right

nnoremap s= yypVr=

augroup vimrc_newfilemagic
	autocmd!
	" Auto mkdir.
	autocmd BufNewFile * autocmd BufWritePre <buffer> ++once
			\ call mkdir(expand("<afile>:p:h"), 'p')
	" Auto chmod +x.
	autocmd BufNewFile * autocmd BufWritePost <buffer> ++once
			\ if getline(1)[:1] ==# '#!'|
			\   silent! call system(['chmod', '+x', '--', expand('<afile>:p')])|
			\ endif
augroup END

function! s:normal_star(wordbounds) abort
	let m = matchlist(getline('.'), '\v(\k*)%'.col('.').'c(\k+)|%'.col('.').'c[^[:keyword:]]*(\k+)')
	if empty(m)
		echohl Error
		echo 'No string under cursor.'
		echohl None
		return ''
	endif
	return '/\V\<'.escape(m[1].m[2].m[3], '\/').'\>'.
		\(!empty(m[1])
			\? '/'.(strlen(m[1]) < strlen(m[2].m[3])
				\? 's+'.(strlen(m[1]))
				\: 'e-'.(strlen(m[2].m[3]) - 1))
			\: '')."\<CR>"
endfunction
nnoremap <expr> *  <SID>normal_star(1)
nnoremap <expr> #  <SID>normal_star(1).'NN'
nnoremap <expr> g* <SID>normal_star(0)
nnoremap <expr> g# <SID>normal_star(0).'NN'

xnoremap <expr> *  'y/<C-r>='."'\\V\\<'.escape(@\", '\\/').'\\>'\<CR>".'/e<CR>'
xnoremap <expr> #  'y/<C-r>='."'\\V\\<'.escape(@\", '\\/').'\\>'\<CR>".'/e<CR>'
xnoremap <expr> g* 'y/<C-r>='."'\\V'.escape(@\", '\\/')\<CR>".'/e<CR>'
xnoremap <expr> g# 'y?<C-r>='."'\\V'.escape(@\", '\\?')\<CR>".'?e<CR>'

silent! unmap Y

nnoremap ! <Cmd>FizzyBuffers<CR>
nnoremap g/ <Cmd>FizzyFiles<CR>

nnoremap <silent><expr> goo ':e %<.'.get({'h': 'c', 'c': 'h', 'hpp': 'cpp', 'cpp': 'hpp'}, expand('%:e'), expand('%:e'))."\<CR>"

nnoremap <C-w>T <C-w>s<C-w>T
nnoremap <C-w>S <C-w>s<C-w>w
nnoremap <C-w>V <C-w>v<C-w>w
nmap <C-w>! :split<CR>!

" Resize window to fit selection.
xmap <expr><silent> <C-w>h ':resize'.(abs(line("v") - line("."))+(2*&scrolloff + 1)).'<CR>'

augroup vimrc_term
	autocmd!

	if has('nvim')
		autocmd TermOpen * call s:term_open()
		autocmd TermClose * stopinsert|nnoremap <buffer> q <C-w>c
	else
		autocmd TerminalOpen *
			\ autocmd InsertEnter * execute 'startinsert|nmap <buffer> <Return> gf'|
			\ autocmd InsertLeave * execute 'stopinsert|nnoremap <buffer> q <C-w>c'
	endif

	tnoremap <C-v> <C-\><C-n>
	"tnoremap <C-w><C-w> <C-\><C-n><C-w><C-w>

	function! s:term_open() abort
		nmap <buffer> <Return> gf

		let b:passthrough = {}
		for x in [
		\  ['<C-d>', 'd'],
		\  ['<C-u>', 'u']
		\]
			execute call('printf', ["nnoremap <silent><nowait><buffer> %s :call <SID>term_passthrough('less', '%s')<CR>"] + x)
		endfor

		startinsert
	endfunction

	function! s:term_passthrough(cmd, keys) abort
		if get(b:passthrough, a:cmd, -1) <# 0
			let pid = matchstr(bufname(), '\vterm://.{-}//\zs\d+\ze:')
			let children = systemlist(['ps', '--no-headers', '-o', 'cmd', '-g', pid])
			let b:passthrough[a:cmd] = 0 <=# match(children, '/'.a:cmd.'$')
		endif

		if !b:passthrough[a:cmd]
			return
		endif

		call feedkeys('a'.a:keys."\<C-\>\<C-n>:\<C-r>=line('w0')+".(line('.') - line('w0'))."\<CR>\<CR>", 'nit')
	endfunction
augroup END

if has('nvim')
IfLocal packadd debugger.nvim
IfSandbox execute ":function! g:DebuggerDebugging(...)\nreturn 0\nendfunction"
else
IfLocal execute ":function! g:DebuggerDebugging(...)\nreturn 0\nendfunction"
endif

augroup vimrc_autoresize
	autocmd! VimResized * wincmd =
augroup END

let s:matchcolors = ['DiffAdd', 'DiffDelete', 'DiffChange']
let s:nmatchcolors = 0
command! -nargs=+ Match call matchadd(s:matchcolors[s:nmatchcolors], <q-args>)|let s:nmatchcolors = (s:nmatchcolors + 1) % len(s:matchcolors)

packadd cfilter

map & <Plug>(JumpMotion)c

command! -nargs=* Termdebug delcommand Termdebug<bar>packadd termdebug<bar>Termdebug <args>

IfLocal noremap <silent> gc :<C-U>unmap gc<CR>:packadd vim-commentr<CR>:call feedkeys('gc', 'i')<CR>

if has('nvim') && &termguicolors
	IfLocal packadd nvim-colorizer.lua
	IfLocal lua require'colorizer'.setup { '*'; '!mail'; '!text' }
endif

nnoremap <expr> s; 'A'.(";:"[&ft == 'python']).'<Esc>'
nnoremap s, A,<Esc>

nnoremap s<C-g> :! stat %<CR>
nnoremap <silent> sw :set wrap!<CR>
nnoremap <silent> sp vip:sort /\v^(#!)@!\A*\zs/<CR>
nnoremap <silent> s~ :set scrollbind!<bar>echo 'set scb='.&scrollbind<CR>

command! -nargs=* -complete=command Capture call s:capture(<q-args> || 'messages')
function! s:capture(cmd) abort
	redir => output
	silent! execute a:cmd
	redir END
	if empty(l:output)
		echohl WarningMsg
		echomsg "no output"
		echohl None
	else
		new
		nnoremap <buffer> q <C-w>c
		setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
		let output = trim(l:output)
		put! =l:output
	endif
endfunction

command! -nargs=* -complete=command Time call s:time(<q-args>)
function! s:time(cmd) abort
	let start = reltime()
	try
		execute a:cmd
	finally
		echomsg 'time' reltimestr(reltime(start)) 's'
	endtry
endfunction

let completecontacts_hide_nicks=1
let completecontacts_query_cmd=
	\ "/usr/bin/abook --mutt-query ''|
	\ awk -F'\\t' 'NR > 1 {print $2\" <\"$1\">\"}'|
	\ fzf -f %s"

let commentr_leader = 'g'
let commentr_uncomment_map = ''
nmap gcD gcdO
nmap gcM gcmO

nnoremap <silent><expr> p <SID>magic_paste('p')
nnoremap <silent><expr> P <SID>magic_paste('P')

function! s:magic_paste(p) abort
	if !(!&paste && ( getregtype(v:register) ==# 'V' ||
	\                (getregtype(v:register) ==# 'v' && empty(getline('.')))))
		return a:p
	endif

	let reg = getreg(v:register)
	let cur_indent = indent('.')
	if cur_indent <=# 0
		let cur_indent = indent(call(a:p ==# 'p' ? 'prevnonblank' : 'nextnonblank', ['.']))
	endif
	return a:p.':call '.matchstr(expand('<sfile>'), '<SNR>.*').'_reindent('.(len(split(reg, "\n", 1)) - (getregtype(v:register) ==# 'V')).','.cur_indent.")\<CR>"
endfunction

function! s:magic_paste_reindent(nlines, cur_indent) abort
	let v:lnum = nextnonblank('.')
	if !empty(&indentexpr)
		let save_cursor = getcurpos()
		" meson.vim is fucked like hell.
		"
		" We need silent! because some brainfucked people put echom inside
		" indentexptr and someone other reviewed it and thought its okay.
		"
		" try...catch also needed just because. Why not? meson.vim shits into the
		" fan, but forgets catching it.
		try
			silent! sandbox let indent = eval(&indentexpr)
		catch
			let indent = 0
		finally
			call setpos('.', save_cursor)
		endtry
	elseif &cindent
		let indent = cindent(v:lnum)
	elseif &lisp
		let indent = lispindent(v:lnum)
	else
		return
	endif

	if indent <=# 0
		let indent = a:cur_indent
	endif

	let indent = (indent - indent(v:lnum)) / shiftwidth()

	execute 'silent! normal!' repeat(a:nlines.(indent < 0 ? '<<' : '>>'), abs(indent))
	normal! _
endfunction

augroup vimrc_stdin
	autocmd! StdinReadPost * setlocal buftype=nofile bufhidden=hide noswapfile
augroup END

if $TERM !=# 'linux'
	augroup vimrc_persistentoptions
		let s:options_vim = (has('nvim') ? stdpath('config') : '~/.vim').'/options.vim'
		function! s:update_options_vim() abort
			try
				execute 'source' fnameescape(s:options_vim)
				let background = &background
				doautocmd Colorscheme
			catch
			endtry
		endfunction
		call s:update_options_vim()

		autocmd!
		autocmd OptionSet background
			\ call writefile([printf('set background=%s', &background)], s:options_vim)|
			\ call system(['/usr/bin/pkill', '--signal', 'SIGUSR1', 'nvim'])
		if has('nvim')
			autocmd Signal SIGUSR1 call s:update_options_vim()|redraw!
		else
			autocmd SigUSR1 call s:update_options_vim()|redraw!
		endif
	augroup END
	" Must be after background
	let colors_name = 'vivid'
endif

colorscheme vivid

augroup vimrc_restorecursor
	autocmd! BufReadPost * autocmd FileType <buffer> ++once autocmd BufEnter <buffer> ++once
		\ if 1 <= line("'\"") && line("'\"") <= line("$") && &filetype !~? '\vgit|commit'|
		\   execute 'normal! g`"zvzz'|
		\ endif
augroup END

augroup vimrc_sessionmagic
	autocmd!
	command! SS source Session.vim
	autocmd VimLeave *
		\ if 0 ==# v:dying && 0 ==# v:exiting && !empty(v:this_session)|
		\   execute 'mksession!' v:this_session|
		\ endif
augroup END

" Recognize user hashes from shell.
cnoremap <expr> / <SID>magic_tilde()
function! s:magic_tilde() abort
	if getcmdtype() !=# ':'
		return '/'
	endif

	let cmdpos = getcmdpos()
	let cmdline = getcmdline()

	" Only for file related operations.
	if cmdline !~# '\v^%((tab)?e%[dit]|r%[ead]|w%[rite]|[lt]?cd|(tab)?new|[tl]?cd|source)>'
		return '/'
	endif

	let word_start = match(strpart(cmdline, -1, cmdpos), '\v.* \zs\~.*')
	if word_start < 0
		return '/'
	endif

	if &shell =~# 'zsh'
		let cmd = join([
			\  'set -eu',
			\  '. $ZDOTDIR/??-hashes*.zsh',
			\  'f=$~0',
			\  'unhash -dm \*',
			\  'print -D -- $f',
			\], "\n")
	endif

	let word = cmdline[word_start:cmdpos]
	let output = trim(system([&shell, '-c', cmd, word]))
	if v:shell_error
		throw 'magic-tilde: '.output
		return '/'
	endif

	return "\<C-\>e\"".escape(strpart(cmdline, 0, word_start).output.'/'.strpart(cmdline, cmdpos), '\"')."\"\<CR>"
endfunction

if !empty($WAYLAND_DISPLAY)
	let clipboard = {
		\  'copy': {
		\     '+': 'wl-copy --foreground --type text/plain',
		\     '*': 'wl-copy --foreground --primary --type text/plain',
		\   },
		\  'paste': {
		\     '+': {-> split(system('wl-paste --no-newline'), '\r\?\n', 1)},
		\     '*': {-> split(system('wl-paste --no-newline --primary'), '\r\?\n', 1)},
		\  },
		\  'cache_enabled': 1,
		\}
endif

let @n = "dd*\<C-w>\<C-w>nzz\<C-w>\<C-w>"

" NVim bug statusline with \n \e \0 (zero width probably) messes up character
" count. Followed by multi-width character crashes attrs[i] > 0.
augroup vimrc_statusline
	autocmd!
	set noshowmode laststatus=2

	set tabline=%!Tabline()
	function! Tabline() abort
		let tabs = ''
		let curtabnr = tabpagenr()
		for tabnr in range(1, tabpagenr('$'))
			let bufnrs = tabpagebuflist(tabnr)
			let winnr = tabpagewinnr(tabnr)
			let bufnr = bufnrs[winnr - 1]

			let tabpath = bufname(bufnr)
			let tabname = '[No Name]'
			if !empty(tabpath)
				let tabname = matchstr(tabpath, '\v([^/]*/)?[^/]*$')
			endif

			let tab = tabnr.':'.tabname

			if getbufvar(bufnr, '&modified')
				let tab .= ' [+]'
			else
				for bufnr in bufnrs
					if getbufvar(bufnr, '&modified')
						let tab .= ' +'
						break
					endif
				endfor
			endif

			let tabs .= '%'.tabnr.'T%#TabLine'.(tabnr == curtabnr ? 'Sel' : '').'# '.tab.' '
		endfor
		return tabs.'%#TabLineFill#%T'
	endfunction

	let g:statusline_lnum_change = ''
	let s:prev_lnum = 0
	autocmd CursorMoved *
		\ let s:lnum = line('.')|
		\ if s:lnum !=# s:prev_lnum|
		\   let g:statusline_lnum_change = printf('%+d', s:lnum - s:prev_lnum)|
		\   let s:prev_lnum = s:lnum|
		\ endif

	autocmd WinLeave,FocusLost *
		\ setlocal statusline=%#StatusLineNC#%n:%f%h%w%(\ %m%)|
		\ setlocal statusline+=%=|
		\ setlocal statusline+=%l/%L:%-3v
	autocmd VimEnter,WinEnter,BufWinEnter,FocusGained *
		\ setlocal statusline=%(%#StatusLineModeTerm#%{'t'==mode()?'\ \ T\ ':''}%#StatusLineModeTermEnd#%{'t'==mode()?'\ ':''}%#StatusLine#%)|
		\ setlocal statusline+=%(\ %{DebuggerDebugging()?'🦋🐛🐝🐞🐧🦠':''}\ %)|
		\ setlocal statusline+=%(%(\ %{!&diff&&argc()>#1?(argidx()+1).'\ of\ '.argc():''}\ %)%(\ \ %{GitBuffer().status}\ %)\ %)|
		\ setlocal statusline+=%n:%f%h%w%{exists('b:gzflag')?'[GZ]':''}%r%(\ %m%)%k|
		\ setlocal statusline+=%9*%<%#StatusLine#|
		\ setlocal statusline+=%<%=|
		\ setlocal statusline+=%1*%2*|
		\ setlocal statusline+=%(\ %{&paste?'ρ':''}\ %)|
		\ setlocal statusline+=%(\ %{&spell?&spelllang:''}\ \ %)|
		\ setlocal statusline+=%(\ %{substitute(&binary?'bin':(!empty(&fenc)?&fenc:&enc).(&bomb?',bom':'').(&fileformat!=#'unix'?','.&fileformat:''),'^utf-8$','','')}\ %)|
		\ setlocal statusline+=%(\ %{!&binary&&!empty(&ft)?&ft:''}\ %)|
		\ setlocal statusline+=%3*\ %l(%{statusline_lnum_change})/%L:%-3v
augroup END

command! -nargs=* DelShada execute 'normal' ':%s/\v^[^ ].*(\n .*){-}\V'.escape(<q-args>, '\/').'\v.*(\n .*)*\n//' "\n"
command! -range URLFilter silent '<,'>!awk '/^http/ {print $1}' | sort -u

delcommand PackCommand
delcommand Ccabbrev
delcommand IfSandbox
delcommand IfLocal
