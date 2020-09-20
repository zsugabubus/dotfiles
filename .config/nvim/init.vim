" gcc: -fdiagnostics-generate-patch

" https://github.com/vim-syntastic/syntastic
" tmux integration: https://gist.github.com/mislav/5189704(
" https://github.com/RRethy/vim-hexokinase
" https://github.com/osyo-manga/vim-hopping
" https://github.com/liuchengxu/vim-clap

" packadd nvim-lsp

" :so $VIMRUNTIME/syntax/hitest.vim

if filewritable(expand(stdpath('config').'/init.vim'))
	command! -nargs=+ IfLocal <args>
	command! -nargs=+ IfSandbox
else
	command! -nargs=+ IfLocal
	command! -nargs=+ IfSandbox <args>
endif

" get rid of shit
let g:loaded_tutor_mode_plugin = 1
let g:loaded_fzf = 1

set nowrap
set ts=8 sw=0 sts=0 noet
set spelllang=en
set ignorecase smartcase
set scrolloff=5 sidescrolloff=23
set splitright
set lazyredraw
set matchpairs+=‘:’,“:”
set timeoutlen=600
set noswapfile
set hidden
set pastetoggle=<F2>
set switchbuf=useopen
" https://gist.github.com/romainl/7e2b425a1706cd85f04a0bd8b3898805
set path+=src/**,include/**
set wildmode=list:longest,full
set wildcharm=<C-Z>
set wildignore+=*.o,*.obj,.git,*.lock,*~
set grepprg=noglob\ rg\ --vimgrep\ --smart-case
set grepformat=%f:%l:%c:%m
set diffopt=filler,vertical,algorithm:patience

" shadon't
IfSandbox set shada="NONE" noundofile nowritebackup

set list
if $TERM !=# 'linux'
	set termguicolors " 24-bit colors. Yuhhuuu.
	set showbreak=+
	" ↪↵\
	set listchars=eol:$,tab:│\ ,trail:•,extends:⟩,precedes:⟨,space:·,nbsp:␣
	set listchars=eol:$,tab:›\ ,trail:•,extends:⟩,precedes:⟨,space:·,nbsp:␣
else
	set showbreak=\\
	set listchars=eol:$,tab:>\ ,trail:+,extends::,precedes::,nbsp:_
end

	" let text = matchstr(getline(v:foldstart), '^.\{-}\S.\{-}\s\{-1}\zs\S.\{-}\ze\(:\?\s*{'.'{{\d\+\)\?$')
	"
function! VimFoldText() abort
	let right = ' ('.string(v:foldend - v:foldstart + 1).' )'
	let text = getline(nextnonblank(v:foldstart))
	let tw = min([(&tw > 0 ? &tw : 80), winwidth('%') - float2nr(ceil(log10(line('$')))) - 1])
	if v:foldlevel ==# 1
		let left = ' ◆ '
	elseif v:foldlevel ==# 2
		let left = '   ▶  '
	else
		let left = '     ● '
	endif
	let left = ' '.repeat('-', v:foldlevel - 1).'+ '

	" if strdisplaywidth(left.text.right) > tw
	" 	while strdisplaywidth(left.text.'…'.right) > tw && !empty(text)
	" 		let text = strcharpart(text, 0, strlen(text) - 1)
	" 	endwhile
	" endif

	let text = text.repeat(' ', tw - strdisplaywidth(left.text.right))

	return left.text.right.repeat(' ', 300)
endfunction

set foldtext=VimFoldText()

set undofile
set undodir=$HOME/.cache/nvim/undo

set nojoinspaces " no double space
" XXX: How autocomplete with last?
set completeopt=menu,longest,noselect,preview

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
nnoremap <expr> + (!&diff ? 'g+' : ":diffput\n")
nnoremap <expr> - (!&diff ? 'g-' : ":diffget\n")
xnoremap <expr> + (!&diff ? '' : ":diffput\n")
xnoremap <expr> - (!&diff ? '' : ":diffget\n")
noremap <expr> > (!&diff ? '>' : ":diffget 2\n")
noremap <expr> < (!&diff ? '<' : ":diffget 3\n")

" jump to merge conflicts
nnoremap <silent> ]= :<C-U>call search('^=======$', 'Wz')<CR>
nnoremap <silent> [= :<C-U>call search('^=======$', 'Wbz')<CR>

" replace f/F and t/T to jump only to the beginning of snake_case or
" PascalCase words if pattern is lowercase; otherwise normal f/F and t/T that
" does not stop at end-of-line
function! g:Magic_char_search(mode, forward) abort
	let cs = getcharsearch()
	let isvisual = a:mode =~# "\\m\\C^[vV\<C-V>]$"
	let escchar = escape(cs.char, '\')
	let lnum = line('.')
	let e = (-!!cs.until + (a:mode ==# 'n' ? 0 : isvisual ? &selection !=# 'inclusive' : 1)) * (cs.forward ==# a:forward ? 1 : -1) " where to positionate cursor
	let pattern = (cs.char =~# '\m\l'
		\ ? '\v\C%(%('.(e ==# -1 ? '\ze\_.' : '').'<|'.(e ==# -1 ? '\ze' : '').'[_])\V\['.tolower(escchar).toupper(escchar).']'
			\ .'\v|'.(e ==# -1 ? '\ze' : '').'[a-z_]\V'.toupper(escchar).'\)'
		\ : (e ==# -1 ? '\ze\_.' : '').'\V'.escchar).(e ==# 1 ? '\_.\ze' : '')
	let flags = 'eW'.(cs.forward ==# a:forward ? 'z' : 'b')
	if isvisual
		normal! gv
	endif
	" hmmm. maybe we could use normal! /search/e... simply; but it works so do
	" not fucking touch it
	for nth in range(1, v:count1)
		call search(pattern, flags)
	endfor
	if line('.') !=# lnum
		echohl WarningMsg
		echo printf('Pattern crossed end-of-line: %s', cs.char)
		echohl Normal
	else
		" to clear above warning
		echo
	endif
endfunction

for s:letter in [',', ';']
	execute printf("nnoremap <silent> %s :call g:Magic_char_search('n', %d)<CR>",
		\ s:letter, s:letter ==# ';')
endfor
for s:letter in ['f', 'F', 't', 'T']
	for s:map in ['n', 'x', 'o']
		execute printf("%snoremap <expr><silent> %s [setcharsearch({'forward': %d, 'until': %d, 'char': nr2char(getchar())}), ':<C-U>call g:Magic_char_search(\"'.mode(1).'\", 1)\<CR>'][1]",
			\ s:map, s:letter, s:letter =~# '\l', s:letter =~? 't')
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

cmap w!! w !sudo tee >/dev/null %

inoremap <expr> <C-j> line('.') ==# line('$') ? "\<C-O>o" : "\<Down>\<End>"

command! -nargs=1 RegEdit let @<args>=input('"'.<q-args>.'=', @<args>)
nnoremap d_ "_dd

nnoremap <expr> m ':echom "'.join(map(map(range(char2nr('a'), char2nr('z')) + range(char2nr('A'), char2nr('Z')), {_,nr-> nr2char(nr)}), {_,mark-> (getpos("'".mark)[1] ==# 0 ? mark : ' ')}), '').'"<CR>m'

" jump to parent indention
nnoremap <silent> <expr> <C-q> '?\v^\s+\zs%<'.indent(prevnonblank('.')).'v\S\|^#@!\S?s-1<CR>
	\ :noh\|call histdel("search", -1)\|let @/ = histget("search", -1)<CR>'

command -nargs=1 Source execute 'source' fnameescape(stdpath('config').'/'.<q-args>)

Source textobject.vim

" visual lines
nnoremap <Up> gk
nnoremap <Down> gj

inoremap <silent> <F9> <C-R>=strftime('%Y%b%d%a %H:%M')<CR>
nnoremap <silent> <M-m> :cclose<bar>update<bar>silent make<CR>
nnoremap <silent> <M-r> :cclose<bar>update<bar>silent make<bar>terminal make run<CR>
nnoremap <silent> <M-n> :cnext<CR>zz
nnoremap <silent> <M-N> :cprev<CR>zz

augroup vimrc_errorformat
	function! s:errorformat_make()
		if 'make' == &makeprg|
			set errorformat^=make:\ %*[[]%f:%l:\ %m|
		endif
	endfunction

	autocmd VimEnter * call s:errorformat_make()
	autocmd OptionSet makeprg call s:errorformat_make()
augroup END

Source swapword.vim

" Always go to file.
" nnoremap <silent> gf :edit <cfile><CR>

" put the first line of the paragraph at the top of the window
" <C-E> does not want to get executed without execute... but <C-O> does... WTF!?
nnoremap <silent><expr> z{ ':set scrolloff=0<bar>:execute "normal! {zt\<lt>C-O>\<lt>C-E>"<bar>:set scrolloff='.&scrolloff.'<CR>'

nnoremap gss :setlocal spell!<CR>
nnoremap gse :setlocal spell spelllang=en<CR>
nnoremap gsh :setlocal spell spelllang=hu<CR>

" nomacs
nnoremap <expr> <M-!> ':edit '.expand('%:h').'/<C-z>'
nnoremap <expr> <M-t> ':tabedit '.expand('%:h').'/<C-z>'
" nnoremap <expr> <M-o> ':edit '.expand('%:h').'/<C-z>'
nnoremap <silent> <M-o> :buffer #<CR>
nnoremap <expr> <M-e> ':edit '.expand('%:h').'/<C-z>'
nnoremap <expr> <M-s> ':split '.expand('%:h').'/<C-z>'
nnoremap <silent> <M-d> :Explore<CR>
nnoremap <silent> <M-x> :Explore<CR>

nnoremap <silent> <M-w> :write<CR>
nnoremap <silent> <M-W> :wall<CR>
nnoremap <silent> <M-u> :bufdo update<CR>
nnoremap <silent> <M-q> :quit<CR>
nnoremap <silent> <M-f> :next<CR>
nnoremap <silent> <M-F> :prev<CR>

" handy yanking to system-clipboard
map gy "+yil
map gY "+yy

" repeat last action over visual block
xnoremap . :normal .<CR>

" execute macro over visual range
xnoremap <expr><silent> @ printf(':normal! @%s<CR>', nr2char(getchar()))

command! SynShow echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')

Source japan.vim

cnoreabbrev <expr> man getcmdtype() == ':' && getcmdpos() == 4 ? 'Man' : 'man'
command! -bar -bang -nargs=+ ManKeyword
	\ try|
	\  silent execute 'Man '.join([<f-args>][:-2], ' ')|
	\  silent keepp execute 'normal /^\v {7}\zs<\V'.escape([<f-args>][-1], '\')."\\>\<CR>"|
	\ catch|
	\  execute 'Man<bang> '.[<f-args>][-1]|
	\ finally|
	\  noh|
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

augroup vimrc_magicq
	autocmd! BufEnter * nnoremap <buffer> q :quit<CR>|
		\ autocmd TextChanged,TextChangedI,TextChangedI,TextChangedP,InsertEnter <buffer=abuf> ++once
			\ silent! nunmap <buffer> q
augroup END

augroup vimrc_skeletons
	autocmd! BufNewFile * autocmd FileType * ++once if 0 == changenr()|call setline(1, get({
		\ 'c':   ['#include <stdio.h>', '', 'int', 'main(int argc, char *argv[])', '{', "\tprintf(\"\");", '}'],
		\ 'cpp': ['#include <stdio.h>', '', 'int', 'main(int argc, char *argv[])', '{', "\tprintf(\"\");", '}'],
		\ 'html': ['<!DOCTYPE html>', '<html>', '<head>', '<meta charset=UTF-8>', '<title>Page Title</title>', '</head>', '<body>', "\t<h1>This is a Heading</h1>", '</body>', '</html>'],
		\ 'sh': ['#!/bin/sh', ''],
		\ 'zsh': ['#!/bin/zsh', ''],
		\ 'bash': ['#!/bin/bash', ''],
		\ 'python': ['#!/usr/bin/env PYTHONDONTWRITEBYTECODE=1 python3', '']
		\}, &filetype, []))|set modified|endif|
		\normal G
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
	
	autocmd FileType html
		\ xnoremap <expr> s<<Space> mode() ==# 'V' ? 'c< <CR><C-r>"><Esc>' : 'c< <C-r>" ><Esc>'|
		\ xnoremap <expr> s<b mode() ==# 'V' ? 'c<lt>b><CR><C-r>"</b><Esc>' : 'c<lt>b><C-r>"</b><Esc>'|
		\ xnoremap <expr> s<i mode() ==# 'V' ? 'c<lt>i><CR><C-r>"</i><Esc>' : 'c<lt>i><C-r>"</i><Esc>'|
		\ xnoremap <expr> s<d mode() ==# 'V' ? 'c<lt>div><CR><C-r>"</div><Esc>' : 'c<lt>div><C-r>"</div><Esc>'
	
	autocmd FileType sh,zsh,dash
		\ setlocal ts=2|
		\ xnoremap <buffer> s< c<<EOF<CR><C-r><C-o>"EOF<CR><Esc><<gvo$B<Esc>i
	
	autocmd FileType plaintex,tex
		\ xnoremap <buffer> sli c\lstinline{<C-r><C-o>"}<Esc>|
		\ xnoremap <buffer> sq c\textquote{<C-r><C-o>"}<Esc>
	
	autocmd FileType vim,lua,javascript,yaml,css,stylus,xml,html,pug,gdb
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
augroup END

augroup vimrc_autoplug
	IfLocal autocmd BufReadPre *.styl ++once packadd vim-stylus
	IfLocal autocmd BufReadPre *.pug  ++once packadd vim-pug
	IfLocal autocmd BufReadPre *.toml ++once packadd vim-toml
	IfLocal autocmd BufReadPre *.md   ++once packadd vim-markdown
	IfLocal autocmd BufReadPre *.glsl ++once packadd vim-glsl

	IfLocal autocmd FileType mail ++nested packadd vim-completecontacts

	" IfLocal packadd debugger.nvim
	IfLocal packadd vim-gnupg
augroup END

" autocmd BufReadPost *rc autocmd BufWinEnter <buffer=abuf> ++once setfiletype cfg

augroup vimrc_autodiffupdate
	autocmd! TextChanged,TextChangedI,TextChangedP * diffupdate
augroup END

nnoremap Q :normal n.<CR>

" Automatically open quickfix and location window and make it modifiable.
augroup vimrc_quickfixfix
	autocmd!
	autocmd QuickFixCmdPost [^l]* silent! botright cwindow
	autocmd FileType qf setlocal modifiable nolist|
		\ highlight qfWarning gui=bold guifg=#a36ac7|highlight qfError gui=bold guifg=#ed407a|highlight qfCode gui=bold|match qfWarning /warning:/|2match qfError /error:/|3match qfCode /‘[^’]*’/|
		\ noremap <expr><silent><buffer> dd ":<C-u>call setqflist(filter(getqflist(), 'v:key!=".(line('.') - 1)."'))<CR>:.".(line('.') - 1)."<CR>"|
		\ noremap <silent><buffer> df :<C-u>call setqflist(filter(getqflist(), 'v:val.bufnr!='.getqflist()[line('.') - 1].bufnr))<CR>|
		\ noremap <expr><silent><buffer> J ":pedit +".(getqflist()[line('.') - 1].lnum)." ".fnameescape(bufname(getqflist()[line('.') - 1].bufnr)).'<CR>j'
	autocmd QuickFixCmdPost l* silent! botright lwindow | setlocal modifiable
	" close non-essential windows on quit
	autocmd QuitPre          * silent! lclose | silent! cclose
augroup END

augroup vimrc_diffquit
	" quit from every diffed window; though quit is forbidden inside windo
	autocmd! QuitPre * if &diff|execute 'windo if winnr() !=# '.winnr().' && &diff|quit|endif'|endif
augroup END

" autocmd BufLeave * if &buftype ==# 'quickfix' | echo 'leaving qf' | endif

cnoreabbrev <expr> ccd getcmdtype() == ':' && getcmdpos() == 4 ? 'cd %:p:h' : 'ccd'
cnoreabbrev <expr> gr getcmdtype() == ':' && getcmdpos() == 3 ? 'silent grep' : 'gr'
cnoreabbrev <expr> . getcmdtype() == ':' && getcmdpos() == 2 ? '@:' : '.'
command! -nargs=* Gr silent grep <args>
command! -nargs=* GR Gr -g !check -g !docs -g !test -g !build -g !tests <args>
xnoremap // y<Esc>:GR <C-r>="'".escape(fnameescape(@"), '\/.*$^~[](){}')."'"<CR><CR>

let pets_joker = ''
" tab or complete
inoremap <expr> <Tab> col('.') > 1 && strpart(getline('.'), col('.') - 2, 3) =~ '^\w' ? "\<C-N>" : "\<Tab>"
cnoremap <expr> <C-z> getcmdtype() == ':' ? '<C-f>A<C-x><C-v>' : '<C-f>A<C-n>'
inoremap <S-Tab> \<C-P>

" wrap text
nmap <silent><expr> cs ':set ve=all<CR>%%v%<Esc>xgvo<Esc>xgvo<Left><Left>s'.nr2char(getchar()).':set ve='.&ve.'<CR>'
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

	" auto mkdir
	autocmd BufNewFile * autocmd BufWritePre  <buffer=abuf> ++once
			\ call mkdir(expand("<afile>:p:h"), 'p')

	" auto chmod +x
	autocmd BufNewFile * autocmd BufWritePost <buffer=abuf> ++once
			\ filetype detect|
			\ if getline(1)[:1] ==# '#!' || index(['sh', 'bash', 'zsh', 'python'], &filetype) >=# 0|
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

nnoremap ! :ls<CR>:b<Space>
nnoremap <M-b> :ls<CR>:b<Space>
nmap <M-g> <M-b>
nnoremap <silent><expr> goo ':e %<.'.get({'h': 'c', 'c': 'h', 'hpp': 'cpp', 'cpp': 'hpp'}, expand('%:e'), expand('%:e'))."\<CR>"
nmap <M-O> goo

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
	autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &number && &buftype ==# '' && !&diff && &filetype !=# 'qf'|set relativenumber	|doautocmd OptionSet relativenumber|endif
	autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &number && &buftype ==# '' && !&diff && &filetype !=# 'qf'|set norelativenumber|doautocmd OptionSet relativenumber|endif
augroup END

set title

autocmd! TermOpen * startinsert
tnoremap <Esc><Esc> <C-\><C-n>

if $TERM !=# 'linux'
	Source theme.vim
	" colors will be called from syn* “system” file. avoid loading heavy theme
	" twice or more
	let colors_name = 'vivid'
endif

" IfLocal packadd vim-devicons
" IfSandbox execute \":function! g:WebDevIconsGetFileTypeSymbol(...)\nreturn ''\nendfunction\"
" IfSandbox execute \":function! g:WebDevIconsGetFileFormatSymbol(...)\nreturn ''\nendfunction\"
IfLocal packadd vim-fugitive
IfSandbox execute ":function! g:FugitiveHead(...)\nreturn ''\nendfunction"

augroup vimrc_statusline
	autocmd!
	" no extra noise
	set noshowmode

	set tabline=%!TabLine()
	function! ShortenPath(path)
		return pathshorten(fnamemodify(matchstr(!empty(a:path) ? a:path : '[No Name]', '\v(^[^:]+://)?\zs.*'), ':~:.'))
	endfunction

	function! TabLine()
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
				" \ FileIcon(path).' '
			let s .=
				\ ShortenPath(path)
				\ .(getbufvar(bufnr, '&modified') ? ' [+]' : anymodified ? ' +' : '')
			let s .= ' '

		endfor

		" Fill remaining space.
		let s .= '%#TabLineFill#%T'

		return s
	endfunction

	function! StatusLineBuffers() abort
		let s = ""
		for bufnr in range(1, bufnr('$'))
			if bufnr != bufnr() && getbufvar(bufnr, '&buflisted')
				let s .= ' '.bufnr.':'.ShortenPath(bufname(bufnr))
			endif
		endfor
		return s
	endfunction

	IfLocal packadd vim-signify
	IfLocal execute "function! StatusLineStat() abort\nreturn sy#repo#get_stats_decorated()\nendfunction"
	IfSandbox execute "function! StatusLineStat() abort\nreturn ''\nendfunction"

	let g:diff_lnum = '      '
	function! s:StatusLineCursorChanged() abort
		let lnum = line('.')
		let g:diff_lnum = printf(' %5s', get(s:, 'prev_lnum', lnum) != lnum ? (lnum > s:prev_lnum ? '+' : '').(lnum - s:prev_lnum) : '')
		let s:prev_lnum = lnum
	endfunction

	" let g:ls_icons = map(split($LS_ICONS, ':'), {_,m-> split(m, '=')})
	" function! FileIcon(path) abort
	" endfunction
	" function! StatusLineFileIcon(path) abort
	" endfunction

	function! StatusLineFiletypeIcon() abort
		return get({'unix': '', 'dos': '', 'mac':''}, &fileformat, '')
	endfunction

	autocmd CursorMoved * call s:StatusLineCursorChanged()

	autocmd BufLeave,WinLeave,BufWinLeave *
		\ setlocal statusline=%n:%f%(\ %m%)|
		\ setlocal statusline+=%=|
		\ setlocal statusline+=%2p%%\ %4l/%-4L:%-3v
	autocmd BufEnter,WinEnter,BufWinEnter *
		\ setlocal statusline=%(%(\ %{!&diff&&argc()>#1?(argidx()+1).'\ of\ '.argc():''}\ %)%(\ \ %{FugitiveHead()}\ %)\ %)|
		\ setlocal statusline+=%n:%f%(%h%w%q%{exists('b:gzflag')?'[GZ]':''}%r%)%(\ %m%)%k%(\ %{StatusLineStat()}%)|
		\ setlocal statusline+=%9*%<%{StatusLineBuffers()}%#StatusLine#|
		\ setlocal statusline+=%=|
		\ setlocal statusline+=%1*%2*|
		\ setlocal statusline+=%(\ %{&paste?'ρ':''}\ %)|
		\ setlocal statusline+=%(\ %{&spell?&spelllang:''}\ \ %)|
		\ setlocal statusline+=\ %{!&binary?((!empty(&fenc)?&fenc:&enc).(&bomb?',bom':'').'\ '.StatusLineFiletypeIcon()):\"bin\ \\uf471\"}|
		\ setlocal statusline+=%(\ \ %{!&binary?!empty(&ft)?&ft:'no\ ft':''}%)|
		\ setlocal statusline+=\ %3*\ %2p%%\ %4l/%-4L%{diff_lnum}:%-3v
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

IfLocal packadd showempty.nvim
" packadd showindent.nvim

command! -nargs=* Termdebug delcommand Termdebug<bar>packadd termdebug<bar>Termdebug <args>

IfLocal noremap <silent> gc :<C-U>unmap gc<CR>:packadd vim-commentr<CR>:call feedkeys('gc', 'i')<CR>

if &termguicolors
	IfLocal packadd nvim-colorizer.lua
	IfLocal lua require'colorizer'.setup { '*'; '!mail'; '!text' }
endif

" noremap s <Plug>(JumpMotion)
" noremap <Plug>(JumpMotion); <Cmd>call JumpMotion(':call JumpMotionColon()\<lt>CR>\")<CR>
noremap <Plug>(JumpMotion)v <Cmd>call JumpMotion(':'.line('.'), '/\v%'.line('.')."l\\zs[^[:blank:][:cntrl:][:punct:]]+\<lt>CR>", '')<CR>
noremap <Plug>(JumpMotion)f <Cmd>call JumpMotion('/\V'.escape(nr2char(getchar()), '/\')."\<lt>CR>")<CR>
noremap <Plug>(JumpMotion)F <Cmd>call JumpMotion('?\V'.escape(nr2char(getchar()), '/\')."\<lt>CR>")<CR>
noremap <Plug>(JumpMotion), <Cmd>call JumpMotion(':'.line('w0'), "/,\<lt>CR>", '')<CR>

function! s:capture(...)
	let cmd = join(a:000, ' ')
	let saved = @"
	redir @"
	silent! execute cmd
	redir END
	let output = copy(@")
	let @" = saved
	if empty(output)
		echoerr "no output"
	else
		new
		setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
		put! =output
	endif
endfunction
command! -nargs=+ -complete=command Capture call s:capture(<f-args>)

nmap ghp <Plug>GitGutterPreviewHunk
nmap ghs <Plug>GitGutterStageHunk
nmap ghu <Plug>GitGutterUndoHunk

let netrw_banner = 0
let netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+'
let netrw_keepdir = 0
autocmd! FileType netrw
	\ nmap <buffer> . -|
	\ nmap <buffer> e :e<Space>

let completecontacts_hide_nicks=1
let completecontacts_query_cmd=
	\ "/usr/bin/abook --mutt-query ''|
	\ awk -F'\\t' 'NR > 1 {print $2\" <\"$1\">\"}'|
	\ fzf -f %s"

let commentr_leader = 'g'
let commentr_uncomment_map = ''
nmap gcD gcdO
nmap gcM gcmO

nnoremap <expr> A !empty(getline('.')) ? 'A' : 'cc'

autocmd! StdinReadPost * setlocal buftype=nofile bufhidden=hide noswapfile

augroup vimrc_restorecursor
	autocmd! BufReadPost * autocmd FileType <buffer=abuf> ++once autocmd BufEnter <buffer=abuf> ++once
		\ if 1 <= line("'\"") && line("'\"") <= line("$") && &filetype !~? 'commit'
		\ |   execute 'normal! g`"zvzz'
		\ | endif
augroup END

augroup vimrc_sessionmagic
	autocmd!
	autocmd VimEnter * ++nested
		\ if empty(filter(copy(v:argv), {idx,val-> idx ># 0 && val[0] !=# '-'})) &&
		\     filereadable('Session.vim')|
		\   source Session.vim|
		\ endif
	autocmd VimLeave *
		\ if 0 ==# v:dying && 0 ==# v:exiting && !empty(v:this_session)|
		\   execute 'mksession!' v:this_session|
		\ endif
augroup END

" local configuration
let s:safe = '~/pro/*'
let s:safepat = glob2regpat(s:safe)

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
