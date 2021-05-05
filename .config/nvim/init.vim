" https://github.com/vim-syntastic/syntastic
" tmux integration: https://gist.github.com/mislav/5189704(
" https://github.com/liuchengxu/vim-clap

" DB https://github.com/tpope/vim-dadbod
" https://github.com/kristijanhusak/vim-dadbod-ui
" packadd nvim-lsp

" https://vimways.org/2018/vim-and-git/
" vim-ninja-feet
" :so $VIMRUNTIME/syntax/hitest.vim

" NVim bug statusline with \n \e \0 (zero width probably) messes up character
" count. Followed by multi-width character crashes attrs[i] > 0.

if filewritable(stdpath('config').'/init.vim')
	command! -nargs=+ IfLocal <args>
	command! -nargs=+ IfSandbox
else
	command! -nargs=+ IfLocal
	command! -nargs=+ IfSandbox <args>
endif

" get rid of shit
let g:loaded_tutor_mode_plugin = 1
let g:loaded_fzf = 1

" Fuck your mother.
nnoremap U <Nop>

set nowrap
set ts=8 sw=0 sts=0 noet
set spelllang=en
set ignorecase fileignorecase wildignorecase smartcase
set scrolloff=5 sidescrolloff=23
set splitright
set cinoptions+=t0,:0,l1
set lazyredraw
set matchpairs+=‘:’,“:”
set timeoutlen=600
set noswapfile
set autowrite
set hidden
set pastetoggle=<F2>
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
set wildmode=list:longest,full
set wildignore+=*.a,*.d,*.o,*.out
set wildignore+=.git
set wildignore+=*.lock,*~,tests/**,t/**,check/**,node_modules
" Rank files lower with no suffix.
set suffixes+=,
set grepprg=noglob\ rg\ --vimgrep\ --smart-case
set grepformat=%f:%l:%c:%m
set diffopt=filler,vertical,algorithm:patience
set nomore
set foldtext=VimFoldText()
set nojoinspaces " no double space
" XXX: How autocomplete with last?
set completeopt=menu,longest,noselect,preview

" Shadon't
IfSandbox set shada="NONE" noundofile nowritebackup
IfLocal set undofile undodir=$HOME/.cache/nvim/undo

set list
set showbreak=\\
if $TERM ==# 'linux'
	set listchars=eol:$,tab:>\ ,trail:+,extends::,precedes::,nbsp:_
else
	set termguicolors " 24-bit colors. Yuhhuuu.
	set listchars=eol:$,tab:│\ ,trail:•,extends:⟩,precedes:⟨,space:·,nbsp:␣
	set listchars=eol:$,tab:›\ ,trail:•,extends:⟩,precedes:⟨,space:·,nbsp:␣
end

	" let text = matchstr(getline(v:foldstart), '^.\{-}\S.\{-}\s\{-1}\zs\S.\{-}\ze\(:\?\s*{'.'{{\d\+\)\?$')
	"
function! VimFoldText() abort
	let right = ' ('.string(v:foldend - v:foldstart + 1).' )'
	let line = getline(nextnonblank(v:foldstart))
	let text = substitute(line, '\v^.{-}<(\w.{-})\s*%(\{\{\{.*)?$', '\1', '')
	let tw = min([(&tw > 0 ? &tw : 80), winwidth('%') - float2nr(ceil(log10(line('$')))) - 1])
	let left = repeat(' ', strdisplaywidth(matchstr(line, '\m^\s*')))
	let text = text.repeat(' ', tw - strdisplaywidth(left.text.right))
	return left.text.right.repeat(' ', 999)
endfunction


" history scroller
cnoremap <C-p> <Up>
cnoremap <C-n> <Down>

" BUG: lnoremap doesn't work
inoremap <M-b> <C-Left>
inoremap <M-f> <C-Right>
cnoremap <M-b> <C-Left>
cnoremap <M-f> <C-Right>

inoremap <C-a> <C-o>_
inoremap <C-e> <C-o>g_<Right>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>

nnoremap U <nop>
nnoremap <expr> + (!&diff ? 'g+' : ":diffput\<CR>")
nnoremap <expr> - (!&diff ? 'g-' : ":diffget\<CR>")
xnoremap <expr> + (!&diff ? '' : ":diffput\<CR>")
xnoremap <expr> - (!&diff ? '' : ":diffget\<CR>")
noremap <expr> > (!&diff ? '>' : ":diffget 2\<CR>")
noremap <expr> < (!&diff ? '<' : ":diffget 3\<CR>")

nnoremap <expr> dL (!&diff ? 'dL' : ":diffget LOCAL\<CR>")
nnoremap <expr> dB (!&diff ? 'dB' : ":diffget BASE\<CR>")
nnoremap <expr> dR (!&diff ? 'dR' : ":diffget REMOTE\<CR>")

vnoremap <C-S> y:!hu <C-R>"<CR>

" jump to merge conflicts
nnoremap <silent> ]= :call search('^=======$', 'Wz')<CR>
nnoremap <silent> [= :call search('^=======$', 'Wbz')<CR>

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
		execute printf("%snoremap <expr><silent> %s [setcharsearch({'forward': %d, 'until': %d, 'char': nr2char(getchar())}), ':<C-U>call <SID>magic_char_search(\"'.mode(1).'\", 1)\<CR>'][1]",
			\ s:map, s:letter, s:letter =~# '\l', s:letter =~? 't')
		" execute printf(\"%snoremap <expr><silent> %s '<Cmd>keeppattern /'.nr2char(getchar()).'\<CR>'\",
			" \ s:map, s:letter)
	endfor
endfor
unlet s:letter s:map

function! s:magic_ctrlg() abort
	let str = matchstr(getline('.')[:col('.')-2], '\m[[{}(=*)+\]!]*$')
	if !empty(str)
		" shiftless Dvorak numbers
		let str = substitute(str, '.', {m-> stridx('*()}+{][!=', m[0])}, 'g')
		return repeat("\<C-h>", strlen(str)).str
	else
		" change case of current word
		return "\<C-g>\<C-U>\<C-o>h\<C-o>g~aw\<C-o>:set ve=onemore\<CR>\<C-g>\<C-U>\<C-o>e\<C-g>\<C-U>\<C-o>l\<C-o>:set ve=".&ve."\<CR>"
	endif
endfunction
inoremap <expr><C-g> <SID>magic_ctrlg()

augroup vimrc_fasttimeout
	autocmd!
	autocmd InsertEnter * let saved_timeoutlen = &timeoutlen|set timeoutlen=500
	autocmd InsertLeave * let &timeoutlen=saved_timeoutlen
augroup END

augroup vimrc_insertempty
	autocmd!
	autocmd InsertLeave * try|if empty(trim(getline('.')))|undojoin|call setline('.', '')|endif|catch /undojoin/|endtry
augroup END

" Reindent inner % lines.
nmap >i >%<<$%<<$%
nmap <i <%>>$%>>$%
" Delete surrounding lines.
nmap d< $<%%dd<C-O>dd

command -nargs=* -bang
	\ Publish execute '!'.(<q-args> =~# '\v^\@|^$|\-\-'
	\   ? '{ noglob git diff --name-only '.<q-args>.' && noglob git diff --name-only --cached '.<q-args>.'; } | sort -u'
	\   : 'printf \%s '.shellescape(expand(<q-args>))
	\ ).' | xargs -r -P2 -I{} '.(<bang>0 ? 'printf "\%s\n" {}' : 'install -Dvm 666 {} '.g:publish_path.'{}')|
	\ if !v:shell_error|
	\   if <bang>1|
	\     call feedkeys("\<CR>", "nt")|
	\     redraw|
	\     echomsg 'Upload succeed'|
	\   endif|
	\ else|
	\   echohl Error|
	\   echomsg 'Upload failed'|
	\   echohl None|
	\ endif
nnoremap <silent> <M-p> :update<bar>Publish %<CR>

inoremap <C-r> <C-r><C-o>

" kO -- Only useful if you have reached the line with a motion.
nnoremap <expr> a "aO"[prevnonblank(line('.')) ==# line('.') - 1 && prevnonblank(line('.') + 1) ==# line('.') + 1]
nnoremap <expr> A !empty(getline('.')) ? 'A' : 'cc'

inoremap <expr> <C-s> strftime("%F")
inoremap <expr> <C-f> expand("%:t:r")

inoremap <expr> <C-j> line('.') ==# line('$') ? "\<C-O>o" : "\<Down>\<End>"

command! -nargs=1 RegEdit let @<args>=input('"'.<q-args>.'=', @<args>)
nnoremap d_ "_dd

nnoremap <expr> m ':echomsg "'.join(map(map(range(char2nr('a'), char2nr('z')) + range(char2nr('A'), char2nr('Z')), {_,nr-> nr2char(nr)}), {_,mark-> (getpos("'".mark)[1] ==# 0 ? mark : ' ')}), '').'"<CR>m'

" jump to parent indention
nnoremap <silent> <expr> <C-q> '?\v^\s+\zs%<'.indent(prevnonblank('.')).'v\S\|^#@!\S?s-1<CR>
	\ :noh\|call histdel("search", -1)\|let @/ = histget("search", -1)<CR>'

command -nargs=1 Source execute 'source' fnameescape(stdpath('config').'/'.<q-args>)

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

" Visual lines.
nnoremap <Up> gk
nnoremap <Down> gj

function! s:make() abort
	let start = strftime('%s')
	echon "\U1f6a7  Building...  \U1f6a7"
	make
	redraw
	let errors = 0
	let warnings = 0
	for item in getqflist()
		if item.text =~? ' error: '
			let errors += 1
		elseif item.text =~? ' warning: '
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
inoremap <silent> <F9> <C-R>=strftime('%Y%b%d%a %H:%M')<CR>
nnoremap <silent> <M-m> :call <SID>make()<CR>
nnoremap <silent> <M-r> :call <SID>make()<CR>:terminal make run<CR>
nnoremap <silent> <M-l> :cnext<CR>zOzz
nnoremap <silent> <M-L> :cprev<CR>zOzz
nnoremap <silent> <M-n> :cnext<CR>zOzz
nnoremap <silent> <M-N> :cprev<CR>zOzz

augroup vimrc_errorformat
	function! s:errorformat_make()
		if 'make' == &makeprg|
			set errorformat^=make:\ %*[[]%f:%l:\ %m
			set errorformat^=make%.%#:\ ***\ %*[[]%f:%l:\ %.%#]\ Error\ %n
			set errorformat^=make%.%#:\ ***\ %*[[]%f:%l:\ %m
			set errorformat^=/usr/bin/ld:\ %f:%l:\ %m
		endif
	endfunction

	autocmd VimEnter * call s:errorformat_make()
	autocmd OptionSet makeprg call s:errorformat_make()
augroup END

" Swap word {{{1
" Swap word word.
nnoremap <silent> Sw ciw<Esc>wviwp`^Pb

" Swap WORD WORD.
nnoremap <silent> SW  = ciW<Esc>wviWp`^PB

" Swap xxx = yyy.
nnoremap <expr> S= ":call feedkeys(\"_vt=BEc\\<LT>Esc>wwv$F,f;F;hp`^P_\", 'nt')\<CR>"
" }}}1

" put the first line of the paragraph at the top of the window
" <C-E> does not want to get executed without execute... but <C-O> does... WTF!?
nnoremap <silent><expr> z{ ':set scrolloff=0<bar>:execute "normal! {zt\<lt>C-O>\<lt>C-E>"<bar>:set scrolloff='.&scrolloff.'<CR>'

nnoremap <silent> gss :setlocal spell!<CR>
nnoremap <silent> gse :setlocal spell spelllang=en<CR>
nnoremap <silent> gsh :setlocal spell spelllang=hu<CR>

" nomacs
nnoremap <expr> <M-!> ':edit '.expand('%:h').'/<C-z>'
nnoremap <expr> <M-t> ':tabedit '.expand('%:h').'/<C-z>'
" nnoremap <expr> <M-o> ':edit '.expand('%:h').'/<C-z>'
nnoremap <silent> <M-o> :buffer #<CR>
nnoremap <expr> <M-e> ':edit '.expand('%:h').'/<C-z>'
nnoremap <expr> <M-s> ':split '.expand('%:h').'/<C-z>'
nnoremap <silent> <M-d> :Explore<CR>
nnoremap <silent> <M-x> :Explore<CR>

nnoremap <silent> <M-w> :Bufdo update<CR>
nnoremap <silent> <M-W> :wall<CR>
nnoremap <silent> <M-q> :quit<CR>
nnoremap <silent> <M-f> :next<CR>
nnoremap <silent> <M-F> :prev<CR>

" Handy yanking to system-clipboard.
map gy "+yil
map gY "+yy

" Repeat last action over visual block.
xnoremap . :normal! .<CR>

command! Bg let &background = 'light' == &background ? 'dark' : 'light'

" Perform glob on all lines.
command! -nargs=* -range Glob silent! execute ':<line1>,<line2>!while read; do print -l $REPLY/'.escape(<q-args>, '!%').'(N) $REPLY'.escape(<q-args>, '!%').'(N); done'

command! -bang -nargs=+ Bufdo let g:bufdo_bufnr = bufnr()|execute 'bufdo<bang>' <q-args>|execute 'buffer' g:bufdo_bufnr|unlet g:bufdo_bufnr

" sweep out untouched buffers
command! Sweep windo let b:no_sweep = 1|Bufdo if (!&modifiable || 0 ==# changenr()) && !exists('b:no_sweep')|bdelete|endif|unlet! b:no_sweep

" execute macro over visual range
xnoremap <expr><silent> @ printf(':normal! @%s<CR>', nr2char(getchar()))

command! SynShow echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')

" Highlight trailing whitespaces.
command! StripTrailingWhite keepjumps keeppatterns lockmarks silent %s/\m\s\+$//e
augroup vimrc_japan
	autocmd!
	autocmd ColorScheme * highlight ExtraWhitespace ctermbg=197 ctermfg=231 guibg=#ff005f guifg=#ffffff
	autocmd FileType,BufReadPost * if &buftype ==# '' && !&readonly && &modifiable && index(['', 'text', 'git', 'gitcommit', 'markdown', 'mail', 'diff'], &filetype) ==# -1 |
		\		call matchadd('ExtraWhitespace', '\v +\t+|\s+%#@!$', 10)|
		\	endif
augroup END

cnoreabbrev <expr> man getcmdtype() == ':' && getcmdpos() == 4 ? 'Man' : 'man'
command! -bar -bang -nargs=+ ManKeyword
	\ try|
	\   silent execute 'Man '.join([<f-args>][:-2], ' ')|
	\   silent keeppattern execute 'normal! /^\v {7}\zs<\V'.escape([<f-args>][-1], '\')."\\>\<CR>"|
	\ catch|
	\   execute 'Man<bang> '.[<f-args>][-1]|
	\ finally|
	\   noh|
	\ endtry

function! Diff(spec) abort
	let ft = &ft

	vertical new

	setlocal bufhidden=wipe buftype=nofile nobuflisted noswapfile
	let l:filetype = ft
	if len(a:spec) ==# 0
		let cmd = '++edit #'
		let name = fnameescape(expand('#').'.orig')
	elseif len(a:spec) ==# 1 && filereadable(a:spec[0])
		let name = a:spec[0]
		let cmd = '++edit '.name
	else
		let cmd = '!git show '.shellescape(a:spec).':#'
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
command! -nargs=? Diff call Diff(<q-args>)

ca emtyp empty
ia emtyp empty
ca emtpy empty
ia emtpy empty

ia dont'  don’t
ia Dont'  Don’t
ia doest' doesn’t
ia Doest' Doesn’t
ia cant'  can’t
ia Cant'  Can’t
ia couldnt' couldn’t
ia Couldnt' Couldn’t
ia isnt'  isn’t
ia Isnt'  Isn’t

ia im'    I’m
ia Im'    I’m
ia its'   it’s
ia Its'   It’s
ia youre' you’re
ia Youre' You’re
ia were'  we’re
ia Were'  We’re

ia id'    I’d
ia Id'    I’d
ia youd'  you’d
ia Youd'  You’d
ia wed'   we’d
ia Wed'   We’d

ia il'    I’ll
ia Il'    I’ll
ia youl'  you’ll
ia Youl'  You’ll
ia wel'   we’ll
ia Wel'   We’ll

function! s:unmap_all(map, prefix)
	redir => mappings
		silent execute a:map.'map' a:prefix
	redir END
	for mapping in split(mappings, "\n")
		execute 'silent!' a:map.'unmap' matchstr(l:mapping, '\v^. *\zs[^ ]+')
	endfor
endfunction

augroup vimrc_skeletons
	autocmd! BufNewFile * autocmd FileType <buffer> ++once
		\ if 0 == changenr()|
		\   call setline(1, get({
		\     'c':   ['#include <stdio.h>', '#include <stdlib.h>', '', 'int', 'main(int argc, char *argv[])', '{', "\tprintf(\"\");", '}'],
		\     'cpp': ['#include <stdio.h>', '', 'int', 'main(int argc, char *argv[])', '{', "\tprintf(\"\");", '}'],
		\     'html': ['<!DOCTYPE html>', '<html>', '<head>', '<meta charset=UTF-8>', '<title>Page Title</title>', '</head>', '<body>', "\t<h1>This is a Heading</h1>", '</body>', '</html>'],
		\     'php': ['<?php'],
		\     'sh': ['#!/bin/sh', ''],
		\     'zsh': ['#!/bin/zsh', ''],
		\     'bash': ['#!/bin/bash', ''],
		\     'python': ['#!/usr/bin/env PYTHONDONTWRITEBYTECODE=1 python3', '']
		\   }, &filetype, []))|
		\ endif|
		\ normal! G
augroup END

augroup vimrc_filetypes
	autocmd!
	autocmd FileType man
		\ set mouse=n|
		\ nnoremap <silent><buffer> gr gg/\v^RETURN<bar>EXIT<CR>:noh<CR>zt|
		\ nnoremap <silent><buffer> ge gg/\m^ERRORS<CR>:noh<CR>zt

	autocmd FileType vim
		\ command! -range Execute execute substitute(join(getline(<line1>, <line2>), "\n"), '\m\n\s*\', '', 'g')

	autocmd FileType mbsyncrc
		\ setlocal keywordprg=:ManKeyword\ 1\ mbsync

	autocmd FileType tmux
		\ setlocal keywordprg=:ManKeyword\ 1\ tmux

	autocmd FileType muttrc,neomuttrc
		\ setlocal ts=4 et keywordprg=:ManKeyword\ 5\ neomuttrc

	autocmd FileType zsh
		\ setlocal keywordprg=:ManKeyword\ 1\ zshall

	autocmd BufRead zathurarc
		\ setlocal ft=cfg keywordprg=:ManKeyword\ 5\ zathurarc

	autocmd FileType gitrebase
		\ for s:cmd in split('pick reword edit squash fixup break drop merge', ' ')|
		\   call s:unmap_all('', 'c'.s:cmd[0])|
		\   execute printf('noremap <silent><buffer> c%s :normal! 0ce%s<Esc>w', s:cmd[0], s:cmd)|
		\ endfor|
		\ for s:cmd in split('llabel treset mmerge', ' ')|
		\   call s:unmap_all('n', 'c'.s:cmd[0])|
		\   execute printf('nnoremap <buffer> c%s cc%s ', s:cmd[0], s:cmd[1:])|
		\ endfor

	autocmd FileType diff
		\ nnoremap <expr> dd '-' == getline('.')[0] ? '0r ' : 'dd'

	autocmd FileType html,php
		\ setlocal equalprg=xmllint\ --encode\ UTF-8\ --html\ --nowrap\ --dropdtd\ --format\ -|
		\ xnoremap <expr><buffer> s<<Space> mode() ==# 'V' ? 'c< <CR><C-r>"><Esc>' : 'c< <C-r>" ><Esc>'|
		\ xnoremap <expr><buffer> sb mode() ==# 'V' ? 'c<lt>b><CR><C-r>"</b><Esc>' : 'c<lt>b><C-r>"</b><Esc>'|
		\ xnoremap <expr><buffer> sp mode() ==# 'V' ? 'c<lt>p><CR><C-r>"</p><Esc>' : 'c<lt>p><C-r>"</i><Esc>'|
		\ xnoremap <expr><buffer> si mode() ==# 'V' ? 'c<lt>i><CR><C-r>"</i><Esc>' : 'c<lt>i><C-r>"</i><Esc>'|
		\ xnoremap <expr><buffer> sd mode() ==# 'V' ? 'c<lt>div><CR><C-r>"</div><Esc>' : 'c<lt>div><C-r>"</div><Esc>'

	autocmd FileType sh,zsh,dash
		\ setlocal ts=2|
		\ xnoremap <buffer> s< c<<EOF<CR><C-r><C-o>"EOF<CR><Esc><<gvo$B<Esc>i

	autocmd FileType php
		\ set makeprg=php\ -lq\ %|
		\ set errorformat=%m\ in\ %f\ on\ line\ %l,%-GErrors\ parsing\ %f,%-G

	autocmd FileType plaintex,tex
		\ xnoremap <buffer> sli c\lstinline{<C-r><C-o>"}<Esc>|
		\ xnoremap <buffer> sq c\textquote{<C-r><C-o>"}<Esc>

	let php_sql_query = 1
	let php_htmlInStrings = 1
	let php_parent_error_close = 1
	autocmd FileType vim,lua,javascript,yaml,css,stylus,xml,php,html,pug,gdb
		\ setlocal ts=2

	let c_gnu = 1
	let c_no_curly_error = 1 " (struct s){ } <-- avoid red
	autocmd FileType c,cpp
		\ setlocal ts=8 fdm=manual

	autocmd FileType json,javascript
		\ setlocal ts=2 suffixesadd+=.js

	autocmd FileType lua
		\ setlocal ts=2 suffixesadd+=.lua

	autocmd FileType gitcommit
		\ command! WTC call setline(1, systemlist(['curl', '-s', 'http://whatthecommit.com/index.txt'])[0])|
		\ syntax match Normal ":bug:" conceal cchar=🐛

	autocmd FileType json
		\ setlocal equalprg=jq

	autocmd FileType xml
		\ setlocal equalprg=xmllint\ --encode\ UTF-8\ --format\ -

	autocmd FileType c,cpp
		\ setlocal equalprg=clang-format

	autocmd FileType gitcommit,markdown
		\ setlocal spell expandtab ts=2

	autocmd FileType man
		\ nnoremap <buffer> // /\v^ {7}\S@=%(.*\n {11,14}\S)@=.{-}\zs\V|
		\ nnoremap <buffer> <space> <C-D>|
		\ nmap <buffer> /- //-

	autocmd FileType mail
		\ setlocal wrap ts=4 et spell|
		\ execute 'normal' '}'|
		\ nnoremap <buffer> Q :x<CR>|
		\ nnoremap <buffer> <silent> gs gg/\C^Subject: \?\zs<CR>:noh<CR>vg_<C-G>|
		\ nnoremap <buffer> <silent> gb gg}

	autocmd FileType c,cpp
		\ ia <buffer> sturct struct

	let netrw_banner = 0
	let netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+'
	let netrw_keepdir = 0
	autocmd FileType netrw
		\ nmap <buffer> . -|
		\ nmap <buffer> e :e<Space>
augroup END

augroup vimrc_colorsreload
	autocmd! BufWritePost colors/*.vim ++nested let &background=&background
augroup END

augroup vimrc_autoplug
	autocmd!
	IfLocal autocmd BufReadPre *.styl ++once packadd vim-stylus
	IfLocal autocmd BufReadPre *.pug  ++once packadd vim-pug
	IfLocal autocmd BufReadPre *.toml ++once packadd vim-toml
	IfLocal autocmd BufReadPre *.glsl ++once packadd vim-glsl
augroup END

IfLocal autocmd FileType mail ++nested packadd vim-completecontacts

" IfLocal packadd debugger.nvim
IfLocal packadd vim-gnupg

augroup vimrc_autodiffupdate
	autocmd! TextChanged,TextChangedI,TextChangedP * if empty(&buftype)|diffupdate|endif
augroup END

nnoremap Q :normal n.<CR>zz

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

augroup vimrc_diffquit
	" quit from every diffed window; though quit is forbidden inside windo
	autocmd! QuitPre * if &diff|execute 'windo if winnr() !=# '.winnr().' && &diff|quit|endif'|endif
augroup END

" autocmd BufLeave * if &buftype ==# 'quickfix' | echo 'leaving qf' | endif
cnoreabbrev <expr> f getcmdtype() == ':' && getcmdpos() == 2 ? 'find'.(' ' !=# v:char ? ' ' : '') : 'f'

cnoreabbrev <expr> cd getcmdtype() == ':' && getcmdpos() == 3 ? (haslocaldir() ? 'lcd' : haslocaldir(-1) ? 'tcd' : 'cd') : 'cd'
cnoreabbrev <expr> ccd getcmdtype() == ':' && getcmdpos() == 4 ? 'cd %:p:h' : 'ccd'

cnoreabbrev <expr> gr getcmdtype() == ':' && getcmdpos() == 3 ? 'GREP' : 'gr'
cnoreabbrev <expr> grh getcmdtype() == ':' && getcmdpos() == 4 ? "GREP -g '*.h'" : 'grh'
cnoreabbrev <expr> . getcmdtype() == ':' && getcmdpos() == 2 ? '@:' : '.'
command! -nargs=* GREP call feedkeys("\<CR>", "nt")|execute 'grep -g !check -g !docs -g !test -g !build -g !tests' substitute(escape((<q-args> =~ '\v^''|%(^|\s)-\w' ? <q-args> : shellescape(<q-args>)), '%#'), '<bar>', '\\<bar>', 'g')
xnoremap // y:GREP -F <C-r>=shellescape(@")<CR><CR>
nnoremap /. /\V.

nnoremap g<C-f> :find <C-r><C-w><C-z><CR>

let pets_joker = ''
" tab or complete
inoremap <expr> <Tab> col('.') > 1 && strpart(getline('.'), col('.') - 2, 3) =~ '^\w' ? "\<C-N>" : "\<Tab>"
cnoremap <expr> <C-z> getcmdtype() == ':' ? '<C-f>A<C-x><C-v>' : '<C-f>A<C-n>'
inoremap <S-Tab> \<C-P>

xnoremap <expr> O (line('v') !=# line('.') ? line('v') < line('.') : col('v') <  col('.')) ? '' : 'o'

" wrap text
nmap <silent> ds %%v%O<Esc>xgv<Left>o<Esc>xgvo<Esc>
nmap <silent><expr> cs 'dsgvs'.nr2char(getchar())
nmap <silent><expr> css 'csa'.getline('.')[col('.')-1]
nmap <silent><expr> csa ':set ve=all<CR>v2i'.nr2char(getchar()).'<Esc>xgvo<Esc>xgvo<Left><Left>s'.nr2char(getchar()).'<Esc>:set ve='.&ve.'<CR>'

xnoremap <silent> s<Esc> <Esc><nop>
xnoremap <silent> <expr> s<Space> mode() ==# 'V' ? 'c<CR><C-r><C-o>"<CR><Esc>' : 'c<Space><C-r><C-o>"<Space><Esc>'
xnoremap <silent> s<CR> c<CR><C-r><C-o>"<CR><Esc>
xnoremap <silent> <expr> s" mode() ==# 'V' ? 'c"""<CR><C-r><C-o>""""<Esc>' : 'c"<C-r><C-o>""<Esc>'
xnoremap <silent> <expr> s' mode() ==# 'V' ? 'c''''''<CR><C-r><C-o>"''''''<Esc>' : 'c''<C-r><C-o>"''<Esc>'
xnoremap <silent> <expr> s` mode() ==# 'V' ? 'c```<CR><C-r><C-o>"```<Esc>' : 'c`<C-r><C-o>"`<Esc>'
xnoremap <silent> <expr> s> mode() ==# 'V' ? 'c<<CR><C-r><C-o>"><Esc>' : 'c<<C-r><C-o>"><Esc>'
for [s:left, s:right] in [['(', ')'], ['[', ']'], ['{', '}']]
	execute "xnoremap <silent> <expr> s".s:right." mode() ==# 'V' ? 'c".s:left."<CR><C-r><C-o>\"".s:right."<Esc>' : 'c".s:left."<C-r><C-o>\"".s:right."<Esc>'"
	execute "xnoremap <silent> <expr> s".s:left."  mode() ==# 'V' ? 'c".s:left."<CR><C-r><C-o>\"".s:right."<Esc>' : line('.') ==# line('v') ? 'c".s:left." <C-r><C-o>\" ".s:right."<Esc>' : 'c".s:left."<C-r><C-o>\"".s:right."<Esc>'"
endfor
xnoremap <silent> <expr> s substitute('c%<C-r><C-o>"%<Esc>', '%', nr2char(getchar()), 'g')
unlet s:left s:right
xnoremap <silent> s<bar> c<bar><C-r><C-o>"<bar><Esc>
xnoremap <silent> s‘ c‘<C-r><C-o>"’<Esc>
xmap <silent> s’ s‘
xmap <silent> ss' s‘
xnoremap <silent> s“ c“<C-r><C-o>"”<Esc>
xmap <silent> s” s“
xmap <silent> ss" s“
xnoremap <silent> s. c.<C-r><C-o>".<Esc>
xnoremap <silent> s: c:<C-r><C-o>":<Esc>
xmap <expr><silent> ss- &spelllang ==# 'en' ? 'c–<C-r><C-o>"–<Esc>' : 'c– <C-r><C-o>" –<Esc>'

IfLocal packadd crazy8.nvim

augroup vimrc_newfilemagic
	autocmd!

	" Auto mkdir.
	autocmd BufNewFile * autocmd BufWritePre <buffer> ++once
			\ call mkdir(expand("<afile>:p:h"), 'p')

	" Auto chmod +x.
	autocmd BufNewFile * autocmd BufWritePost <buffer> ++once
			\ if getline(1)[:1] ==# '#!' || '#' ==# &commenstring[0]|
			\   silent! call system(['chmod', '+x', '--', expand('%')])|
			\ endif
augroup END

function! s:normal_star(wordbounds) abort
	let m = matchlist(getline('.'), '\v(\w*)%'.col('.').'c(\w+)|%'.col('.').'c\W+(\w+)')
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

function! s:goto_function() abort
	let what = expand('<cword>')
	if empty(what)
		return
	endif
	let pattern = get({
	\  'php': 'function\s+\b\0\b'
	\}, &filetype, '\0')
	execute 'GREP' shellescape(substitute(pattern, '\\0', what, '')) '-m1'
endfunction
nnoremap <silent> g?f :call <SID>goto_function()<CR>

nnoremap ! :ls<CR>:b<Space>
nnoremap g/ :!ls --group-directories-first<CR>:find *
nnoremap <silent><expr> goo ':e %<.'.get({'h': 'c', 'c': 'h', 'hpp': 'cpp', 'cpp': 'hpp'}, expand('%:e'), expand('%:e'))."\<CR>"

nnoremap <C-w>T <C-w>s<C-w>T
nnoremap <C-w>S <C-w>s<C-w>w
nnoremap <C-w>V <C-w>v<C-w>w
nmap <C-w>! :split<CR>!
nmap <silent><expr> <C-w>go ':tabdo windo if bufnr() ==# '.bufnr().' <bar> :bnext <bar> endif<CR>:'.bufnr().'bdelete<CR>:'.tabpagenr().'tabnext<CR>'

" resize window to fit selection
xmap <expr><silent> <C-w>h ':resize'.(abs(line("v") - line("."))+(2*&scrolloff + 1)).'<CR>'

IfLocal command! PackUpdate execute 'terminal' printf('find %s -mindepth 3 -maxdepth 3 -type d -exec printf \%%s:\\n {} \; -execdir git -C {} pull \;', shellescape(stdpath('data').'/site/pack'))

set number relativenumber
augroup vimrc_numbertoggle
	autocmd!
	autocmd FocusGained,InsertLeave,WinEnter,TermEnter * ++nested
		\ if &number && &buftype ==# '' && !&diff && &filetype !=# 'qf'|
		\   set relativenumber|
		\ endif
	autocmd FocusLost,InsertEnter,WinLeave,TermLeave * ++nested
		\ if &number && &buftype ==# '' && !&diff && &filetype !=# 'qf'|
		\   set norelativenumber|
		\ endif
augroup END

set title

augroup vimrc_term
	autocmd!
	autocmd TermOpen * startinsert|nmap <buffer> <Return> gf
	autocmd TermClose * stopinsert|nnoremap <buffer> q <C-w>c
	tnoremap <C-v> <C-\><C-n>
augroup END

if $TERM !=# 'linux'
	Source theme.vim
	let colors_name = 'vivid'
endif

IfLocal packadd debugger.nvim
IfSandbox execute ":function! g:DebuggerDebugging(...)\nreturn 0\nendfunction"

augroup vimrc_autoresize
	autocmd! VimResized * wincmd =
augroup END

function! s:git_pager_update(bufnr, cmdline)
	let blob = systemlist(['git'] + a:cmdline, [], 1)

	setlocal modifiable
	let new = !empty(getbufline(a:bufnr, 2))
	call setbufline(a:bufnr, 1, blob)
	call deletebufline(a:bufnr, line('$'), '$')
	setlocal readonly nomodifiable
	if new
		call setpos('.', [a:bufnr, 1, 1])
	endif

	filetype detect
endfunction

nnoremap <silent><expr> gf (0 <=# match(expand('<cfile>'), '\v^\x{4,}$') ? ':pedit git://'.fnameescape(expand('<cfile>'))."\<CR>" : 0 <=# match(expand('<cfile>'), '^[ab]/') ? 'viWof/lgf' : 'gf')

function! s:git_pager(cmdline)
	nnoremap <buffer> q <C-w>c

	setlocal nobuflisted bufhidden=hide buftype=nofile noswapfile undolevels=-1

	autocmd ShellCmdPost,VimResume <buffer> call s:git_pager_update(<abuf>, a:cmdline)
	call s:git_pager_update(bufnr(), a:cmdline)
endfunction

function! s:git_status(...) range
	let status = systemlist(['git', 'status', '-sb'])
	if v:shell_error
		let status = []
	endif
	let list = []
	for path in status
		let [_, status, pathname; _] = matchlist(path, '\v(..) (.*)')
		if status ==# '##'
			continue
		endif
		" See git-status.
		if status ==# ' m'
			let status = 'submodule modified'
		elseif status ==# ' M'
			let status = 'modified'
		elseif status ==# '??'
			let status = 'untracked'
		endif
		call add(list, { 'filename': pathname, 'text': status, 'lnum': 1, })
	endfor
	call setqflist(list)
	copen
endfunction

function! s:git_diff(...) range
	let rev = get(a:000, 0, 'HEAD')
	if rev[0] ==# '~'
		let rev = '@'.rev
	endif

	diffthis
	execute 'vsplit git://'.fnameescape(rev).':./'.fnameescape(expand('%'))
	setlocal bufhidden=wipe
	autocmd BufUnload <buffer> diffoff
	diffthis
	wincmd p
	wincmd L
endfunction

" command! -nargs=* -range Gjump call s:git_diff(<f-args>)
command! -nargs=* -range Gdiff call s:git_diff(<f-args>)
command! -nargs=* -range=% Glog
	\ if <line1> ==# 1 && <line2> ==# line('$')|
	\   execute "terminal noglob git log-vim ".<q-args>|
	\ else|
	\   vertical new|
	\   call s:git_pager(['log', '-L<line1>,<line2>:'.expand('#')])|
	\ endif
command! -nargs=* -range Gstatus call s:git_status(<f-args>)

function! s:is_slow_fs(path)
	return 0 <=# index(['fuseblk'], get(systemlist(['stat', '-f', fnamemodify(a:path, ':p'), '-c', '%T']), 0, ''))
endfunction

function! s:git_read()
	call s:git_pager(['show', matchstr(expand("<amatch>"), '\m://\zs.*')])
endfunction

function! s:git_ignore_stderr(chan_id, data, name) dict
endfunction

function! s:git_statusline_update() dict
	if !empty(self.dir)
		let self.status =
		\ (self.bare ? 'BARE:' : self.inside ? 'GIT_DIR:' : '').
		\ self.head.
		\ ("S"[!self.staged]).("M"[!self.modified]).("U"[!self.untracked]).
		\ (self.ahead || self.behind
		\    ? '{'.
		\      (self.ahead ? '+'.self.ahead : '').
		\      (self.behind ? (self.ahead ? '/' : '').'-'.self.behind : '')
		\    .'}'
		\    : '').
		\ (!empty(self.operation)
		\   ? ' ['.self.operation.(self.step ? ' '.self.step.'/'.self.total : '').']'
		\   : '')
	else
		let self.status = ''
	endif
	redrawstatus!
endfunction

function! s:git_status_on_behind_ahead(chan_id, data, name) dict
	if len(a:data) <=# 1
		return
	endif
	let [_, self.git.behind, self.git.ahead; _] = matchlist(a:data[0], '\v^(\d+)\t(\d+)$')
	call call('s:git_statusline_update', [], self.git)
endfunction

function! s:git_status_on_head(chan_id, data, name) dict
	if len(a:data) <=# 1
		return
	endif
	let self.git.head = a:data[0]
	call call('s:git_statusline_update', [], self.git)
endfunction

function! s:git_status_on_status(chan_id, data, name) dict
	if len(a:data) <=# 1
		return
	endif
	let self.git.staged = 0 <=# match(a:data, '^\m[MARC]')
	let self.git.modified = 0 <=# match(a:data, '^\m.[MARC]')
	let self.git.untracked = 0 <=# match(a:data, '^\m\n??')
	call call('s:git_statusline_update', [], self.git)
endfunction

function! s:git_status_on_bootstrap(chan_id, data, name) dict
	if 1 <# len(a:data)
		let [self.git.dir, self.git.bare, self.git.inside, self.git.head; _] = a:data
		let self.git.bare = self.git.bare ==# 'true'
		let self.git.inside = self.git.inside ==# 'true'

		if !self.git.inside
			call jobstart(['git', '--no-optional-locks', '-C', self.git.wd, 'status', '--porcelain'], {
			\  'pty': 0,
			\  'stdout_buffered': 1,
			\  'stderr_buffered': 1,
			\  'on_stdout': function('s:git_status_on_status'),
			\  'on_stderr': function('s:git_ignore_stderr'),
			\  'git': self.git
			\})
		endif

		call jobstart(['git', '--no-optional-locks', '-C', self.git.dir, 'rev-list', '--count', '--left-right', '--count', '@{upstream}...@'], {
		\  'pty': 0,
		\  'stdout_buffered': 1,
		\  'stderr_buffered': 1,
		\  'on_stdout': function('s:git_status_on_behind_ahead'),
		\  'on_stderr': function('s:git_ignore_stderr'),
		\  'git': self.git
		\})

		" sequencer/todo
		if isdirectory(self.git.dir.'/rebase-merge')
			let self.git.operation = 'rebase'
			let self.git.head = readfile(self.git.dir.'/rebase-merge/head-name')[0]
			try
				let self.git.step = +readfile(self.git.dir.'/rebase-merge/msgnum')[0]
				let self.git.total = +readfile(self.git.dir.'/rebase-merge/end')[0]
			catch
				" Editing message.
			endtry
		elseif isdirectory(self.git.dir.'/rebase-apply')
			if file_readable(self.git.dir.'/rebase-apply/rebasing')
				let self.git.head = readfile(self.git.dir.'/rebase-merge/head-name')[0]
				let self.git.operation = 'rebase'
			elseif file_readable(self.git.dir.'/rebase-apply/applying')
				let self.git.operation = 'am'
			else
				let self.git.operation = 'am/rebase'
			endif
			try
				let self.git.step = +readfile(self.git.dir.'/rebase-apply/next')[0]
				let self.git.total = +readfile(self.git.dir.'/rebase-apply/last')[0]
			catch
				" Editing message.
			endtry
		elseif file_readable(self.git.dir.'/MERGE_HEAD')
			let self.git.operation = 'merge'
		elseif file_readable(self.git.dir.'/CHERRY_PICK_HEAD')
			let self.git.operation = 'cherry-pick'
		elseif file_readable(self.git.dir.'/REVERT_HEAD')
			let self.git.operation = 'revert'
		elseif file_readable(self.git.dir.'/BISECT_LOG')
			let self.git.operation = 'bisect'
		endif

		if self.git.head ==# 'HEAD'
			" Detached.
			call jobstart(['git', '--no-optional-locks', '-C', self.git.dir, 'name-rev', '--name-only', self.git.head], {
			\  'pty': 0,
			\  'stdout_buffered': 1,
			\  'stderr_buffered': 1,
			\  'on_stdout': function('s:git_status_on_head'),
			\  'on_stderr': function('s:git_ignore_stderr'),
			\  'git': self.git
			\})
		endif

		let self.git.head = substitute(self.git.head, '^refs/heads/', '', '')
	endif

	call call('s:git_statusline_update', [], self.git)
endfunction

" git --no-optional-locks rev-list --walk-reflogs --count refs/stash
" /usr/share/git/git-prompt.sh
function! GitStatus()
	let dir = getcwd()
	if !has_key(g:git, dir)
		let g:git[dir] = {
		\  'dir': '',
		\  'wd': dir,
		\  'inside': 0,
		\  'staged': 0,
		\  'modified': 0,
		\  'untracked': 0,
		\  'behind': 0,
		\  'ahead': 0,
		\  'operation': '',
		\  'step': 0,
		\  'total': 0,
		\  'status': '...'
		\}
		call jobstart(['git', '--no-optional-locks', '-C', dir, 'rev-parse', '--abbrev-ref', '--absolute-git-dir', '--is-bare-repository', '--is-inside-git-dir', '@'], {
		\  'pty': 0,
		\  'stdout_buffered': 1,
		\  'stderr_buffered': 1,
		\  'on_stdout': function('s:git_status_on_bootstrap'),
		\  'on_stderr': function('s:git_ignore_stderr'),
		\  'git': g:git[dir]
		\})
	endif
	return g:git[dir]['status']
endfunction

augroup vimrc_git
	autocmd!

	autocmd ShellCmdPost,TermLeave,VimResume * let g:git = {}
	doautocmd ShellCmdPost

	autocmd BufReadCmd git://* ++nested call s:git_read()

	" Highlight conflict markers.
	autocmd Colorscheme * match ErrorMsg '^\(<\|=\|>\)\{7\}\([^=].\+\)\?$'
augroup END

augroup vimrc_statusline
	autocmd!
	" No extra noise.
	set noshowmode

	set tabline=%!Tabline()
	function! ShortenPath(path)
		return pathshorten(fnamemodify(matchstr(!empty(a:path) ? a:path : '[No Name]', '\v(^[^:]+://)?\zs.*'), ':~:.'))
	endfunction

	" function! s:get_file_icon()
	" 	let b:icon = get(b:, 'icon', matchstr(substitute(system(['ls', '--color=always', '-d1', '--', bufname()]), \"\e[^m]*m\", '', 'g'), '..'))
	" 	return b:icon
	" endfunction

	function! Tabline()
		let s = ''
		let curr = tabpagenr()
		for n in range(1, tabpagenr('$'))
			" Select the highlighting.
			let s .= n == curr ? '%#TabLineSel#' : '%#TabLine#'

			" Set the tab page number (for mouse clicks).
			let s .= '%'.n.'T '

			" Prefix number.
			let s .= n.':'

			let buflist = tabpagebuflist(n)
			let winnr = tabpagewinnr(n)

			let anymodified = 0
			for bufnr in buflist
				let anymodified += getbufvar(bufnr, '&modified')
			endfor

			let bufnr = buflist[winnr - 1]
			let path = bufname(bufnr)
			let s .=
				\ ShortenPath(path)
				\ .(getbufvar(bufnr, '&modified') ? ' [+]' : anymodified ? ' +' : '')
			let s .= ' '

		endfor

		" Fill remaining space.
		let s .= '%#TabLineFill#%T'

		return s
	endfunction

	let g:recent_buffers = []
	function! StatusLineRecentBuffers() abort
		let s = ''
		let altbufnr = bufnr('#')
		for bufnr in g:recent_buffers
			if bufnr != bufnr() && getbufvar(bufnr, '&buflisted') && index(['quickfix', 'prompt'], getbufvar(bufnr, '&buftype')) ==# -1
				let s .= (bufnr ==# altbufnr ? '#' : bufnr).':'.ShortenPath(bufname(bufnr)).' '
				if &columns <= strlen(s)
					break
				endif
			endif
		endfor
		return s
	endfunction

	" IfLocal packadd vim-signify
	" IfLocal execute \"function! StatusLineStat() abort\nreturn sy#repo#get_stats_decorated()\nendfunction\"
	execute "function! StatusLineStat() abort\nreturn ''\nendfunction"

	let g:diff_lnum = '    '
	function! s:StatusLineCursorChanged() abort
		let lnum = line('.')
		let g:diff_lnum = printf('%4s', get(s:, 'prev_lnum', lnum) != lnum ? (lnum > s:prev_lnum ? '+' : '').(lnum - s:prev_lnum) : '')
		let s:prev_lnum = lnum
	endfunction

	function! StatusLineFiletypeIcon() abort
		return get({ 'unix': '', 'dos': '', 'mac': '' }, &fileformat, '')
	endfunction

	autocmd CursorMoved * call s:StatusLineCursorChanged()

		" \ setlocal statusline+=%2p%%\ %4l/%-4L:%-3v
	autocmd WinLeave,BufWinLeave *
		\ setlocal statusline=%n:%f%(\ %m%)|
		\ setlocal statusline+=%=|
		\ setlocal statusline+=%2p%%\ %4l/%-4L\ L:%-3v\ C
	autocmd WinEnter,BufWinEnter *
		\ setlocal statusline=%(%#StatusLineModeTerm#%{'t'==mode()?'\ \ T\ ':''}%#StatusLineModeTermEnd#%{'t'==mode()?'\ ':''}%#StatusLine#%)|
		\ setlocal statusline+=%(\ %{DebuggerDebugging()?'🦋🐛🐝🐞🐧🦠':''}\ %)|
		\ setlocal statusline+=%(%(\ %{!&diff&&argc()>#1?(argidx()+1).'\ of\ '.argc():''}\ %)%(\ \ %{GitStatus()}\ %)\ %)|
		\ setlocal statusline+=%n:%f%(%h%w%{exists('b:gzflag')?'[GZ]':''}%r%)%(\ %m%)%k%(\ %{StatusLineStat()}%)|
		\ setlocal statusline+=%9*%<%(\ %{StatusLineRecentBuffers()}%)%#StatusLine#|
		\ setlocal statusline+=%=|
		\ setlocal statusline+=%1*%2*|
		\ setlocal statusline+=%(\ %{&paste?'ρ':''}\ %)|
		\ setlocal statusline+=%(\ %{&spell?&spelllang:''}\ \ %)|
		\ setlocal statusline+=\ %{!&binary?(substitute((!empty(&fenc)?&fenc:&enc).(&bomb?',bom':'').'\ ','\\m^utf-8\ $','','').StatusLineFiletypeIcon()):\"bin\ \\uf471\"}|
		\ setlocal statusline+=%(\ \ %{!&binary?!empty(&ft)?&ft:'no\ ft':''}%)|
		\ setlocal statusline+=\ %3*\ %2p%%\ %4l/%-4L\ %{diff_lnum}\ L:%3v\ C
augroup END

augroup vimrc_recentbuffers
	autocmd!
	autocmd InsertEnter,BufWipeout * let s:index = index(g:recent_buffers, bufnr())|if s:index >= 0|silent! unlet! g:recent_buffers[s:index]|endif
	autocmd InsertEnter * call insert(g:recent_buffers, bufnr())
augroup END

let s:matchcolors = ['DiffAdd', 'DiffDelete', 'DiffChange']
let s:nmatchcolors = 0
command! -nargs=+ Match call matchadd(s:matchcolors[s:nmatchcolors], <q-args>)|let s:nmatchcolors = (s:nmatchcolors + 1) % len(s:matchcolors)

" Delay loading of vim-jumpmotion.
IfLocal noremap <silent> <Space> :<C-U>unmap <lt>Space><CR>:packadd vim-jumpmotion<CR>:call feedkeys(' ', 'i')<CR>

IfLocal packadd vim-paperplane
IfLocal packadd vim-pets
IfLocal packadd vim-mall
IfLocal packadd vim-vnicode

IfLocal packadd vim-fuzzysearch

" IfLocal packadd showempty.nvim
" IfLocal packadd showindent.nvim

command! -nargs=* Termdebug delcommand Termdebug<bar>packadd termdebug<bar>Termdebug <args>

IfLocal noremap <silent> gc :<C-U>unmap gc<CR>:packadd vim-commentr<CR>:call feedkeys('gc', 'i')<CR>

if &termguicolors
	IfLocal packadd nvim-colorizer.lua
	IfLocal lua require'colorizer'.setup { '*'; '!mail'; '!text' }
endif

nnoremap s; A;<Esc>
nnoremap s, A,<Esc>

nnoremap s<C-g> :! stat %<CR>
nnoremap sw :set wrap!<CR>
nnoremap sp vip:sort /\a/<CR>
nnoremap ss vip:sort /['"]/<CR>
nnoremap si vip:sort i /['"]/<CR>
nnoremap sb :set scrollbind!<bar>echo 'set scb='.&scrollbind<CR>

" noremap <Plug>(JumpMotion); <Cmd>call JumpMotion(':call JumpMotionColon()\<lt>CR>\")<CR>
noremap <Plug>(JumpMotion)v <Cmd>call JumpMotion(':'.line('.'), '/\v%'.line('.')."l\\zs[^[:blank:][:cntrl:][:punct:]]+\<lt>CR>", '')<CR>
noremap <Plug>(JumpMotion)f <Cmd>call JumpMotion('/\V'.escape(nr2char(getchar()), '/\')."\<lt>CR>")<CR>
noremap <Plug>(JumpMotion)F <Cmd>call JumpMotion('?\V'.escape(nr2char(getchar()), '/\')."\<lt>CR>")<CR>
noremap <Plug>(JumpMotion), <Cmd>call JumpMotion(':'.line('w0'), "/,\<lt>CR>", '')<CR>

function! s:capture(cmd)
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
command! -nargs=+ -complete=command Capture call s:capture(<q-args>)

let completecontacts_hide_nicks=1
let completecontacts_query_cmd=
	\ "/usr/bin/abook --mutt-query ''|
	\ awk -F'\\t' 'NR > 1 {print $2\" <\"$1\">\"}'|
	\ fzf -f %s"

let commentr_leader = 'g'
let commentr_uncomment_map = ''
nmap gcD gcdO
nmap gcM gcmO

function! s:magic_paste_reindent(nlines, def_indent)
	let v:lnum = nextnonblank('.')
	if !empty(&indentexpr)
		let save_cursor = getcurpos()
		sandbox let indent = eval(&indentexpr)
		call setpos('.', save_cursor)
	elseif &cindent
		let indent = cindent(v:lnum)
	else
		return
	endif

	if indent <=# 0
		let indent = a:def_indent
	endif

	let indent = (indent - indent(v:lnum)) / shiftwidth()

	execute 'silent! normal!' repeat(a:nlines.(indent < 0 ? '<<' : '>>'), abs(indent))
	normal! _
endfunction

function! s:magic_paste(p)
	if !(!&paste && ( getregtype(v:register) ==# 'V' ||
	\                (getregtype(v:register) ==# 'v' && empty(getline('.')))))
		return a:p
	endif

	let reg = getreg(v:register)
	return a:p.':call '.matchstr(expand('<sfile>'), '<SNR>.*').'_reindent('.(len(split(reg, "\n", 1)) - (getregtype(v:register) ==# 'V')).','.indent('.').")\<CR>"
endfunction

nnoremap <silent><expr> p <SID>magic_paste('p')
nnoremap <silent><expr> P <SID>magic_paste('P')

augroup vimrc_stdin
	autocmd! StdinReadPost * setlocal buftype=nofile bufhidden=hide noswapfile
augroup END

augroup vimrc_persistentoptions
	let s:options_vim = stdpath('config').'/options.vim'
	function! s:update_options_vim()
		try
			execute 'source' fnameescape(s:options_vim)
		catch
		endtry
	endfunction
	call s:update_options_vim()

	autocmd!
	autocmd OptionSet background
		\ call writefile([printf('set background=%s', &background)], s:options_vim)|
		\ call system(['/usr/bin/pkill', '--signal', 'SIGUSR1', 'nvim'])
	autocmd Signal SIGUSR1 call s:update_options_vim()|redraw!
augroup END

augroup vimrc_autosave
	autocmd! Signal SIGUSR1 silent! Bufdo update
augroup END

augroup vimrc_restorecursor
	autocmd! BufReadPost * autocmd FileType <buffer> ++once autocmd BufEnter <buffer> ++once
		\ if 1 <= line("'\"") && line("'\"") <= line("$") && &filetype !~? 'commit'|
		\   execute 'normal! g`"zvzz'|
		\ endif
augroup END

augroup vimrc_sessionmagic
	autocmd!
	autocmd VimEnter * ++nested
		\ if empty(filter(copy(v:argv), {idx,val-> idx ># 0 && val[0] !=# '-'})) &&
		\    filereadable('Session.vim')|
		\   source Session.vim|
		\ endif
	autocmd VimLeave *
		\ if 0 ==# v:dying && 0 ==# v:exiting && !empty(v:this_session)|
		\   execute 'mksession!' v:this_session|
		\ endif
augroup END

function! s:cmagic_tilde() abort
	if getcmdtype() !=# ':'
		return '/'
	endif

	let cmdpos = getcmdpos()
	let cmdline = getcmdline()

	" Only for file related operations.
	if cmdline !~# '\v^%(e%[dit]|w%[rite]|[lt]?cd)>'
		return '/'
	endif

	let word_start = match(strpart(cmdline, -1, cmdpos), '\v.* \zs\~.*')
	if word_start < 0
		return '/'
	endif

	if &shell =~# 'zsh'
		let cmd = join([
		\  '. $ZDOTDIR/hashes.zsh',
		\  'eval text=$1',
		\  'unhash -dm \*',
		\  'print -D -- $text'
		\], "\n")
	endif

	let word = cmdline[word_start:cmdpos]
	let word = trim(system([&shell, '-c', cmd, '', word]))

	return "\<C-\>e\"".escape(strpart(cmdline, 0, word_start).word.'/'.strpart(cmdline, cmdpos), '\"')."\"\<CR>"
endfunction

cnoremap <expr> / <SID>cmagic_tilde()

let @p = "i\<C-R>+\<CR>\<Esc>"
" Make typedef and struct from typedef struct.
let @s = "0ldt;h%hPpa;\<Esc>v0y{O\<Esc>jpjdwf ;dEO\<Esc>"
let @n = "dd*\<C-w>\<C-w>nzz\<C-w>\<C-w>"

" local configuration
let s:safe = ['~/pro/*', '~/**']
let s:safepat = join(map(s:safe, {_,path-> glob2regpat(path)}), '\|')

try
	let s:dir = system(['/usr/bin/pwd', '-L'])[:-2]
catch
	let s:dir = getcwd()
endtry

while s:dir !=# '/'
	let s:filepath = s:dir.'/.vimrc'
	if fnamemodify(s:dir, ':~') =~ s:safepat && filereadable(s:filepath)
		execute 'source' fnameescape(s:filepath)
	endif
	let s:dir = fnamemodify(s:dir, ':h')
endwhile
unlet! s:dir s:filepath s:safe s:safepat

delcommand Source

delcommand IfSandbox
delcommand IfLocal
