" nvim -u NONE --cmd 'profile start profile|profile file *|source ~/.config/nvim/init.vim|profile stop'
" :so $VIMRUNTIME/syntax/hitest.vim

" Before filetype plugin.
packadd vim-elephant
packadd vim-newfile

packadd! nvim-colorcolors
packadd! vim-acid
packadd! vim-betterm
packadd! vim-bufgrep
packadd! vim-dent
packadd! vim-difficooler
packadd! vim-fizzy
packadd! vim-fuzzysearch
packadd! vim-git
packadd! vim-japan
packadd! vim-make
packadd! vim-mall
packadd! vim-mankey
packadd! vim-pastereindent
packadd! vim-pets
packadd! vim-qf
packadd! vim-reload
packadd! vim-star
packadd! vim-stdin
packadd! vim-surround
packadd! vim-textobjects
packadd! vim-themember
packadd! vim-tilde
packadd! vim-vnicode
packadd! vim-woman
packadd! vim-wtc7
packadd! vim-wtf

set shortmess+=mrFI
set nowrap
setglobal ts=8 sw=0 sts=0 noet
set ignorecase fileignorecase wildignorecase smartcase
set scrolloff=5 sidescrolloff=23
set nrformats-=octal
set splitright
set cinoptions+=t0,:0,l1
set autoindent
set copyindent
set lazyredraw
set matchpairs+=‘:’,“:”
set mouse=
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
set suffixes+=, " Rank files lower with no suffix.
set wildcharm=<C-Z>
set wildmenu
set wildmode=list:longest,full
set wildignore+=.git
set wildignore+=*.lock,*~,node_modules
set completeopt=menu,longest,noselect,preview
set diffopt=filler,vertical,algorithm:patience
set nomore
set nojoinspaces " No double space.
if filewritable(stdpath('config').'/init.vim')
	set undofile undodir=$HOME/.cache/nvim/undo
else
	set noundofile shada="NONE"
endif
set list
set showbreak=\\
if $TERM ==# 'linux'
	set listchars=eol:$,tab:>\ ,trail:+,extends::,precedes::,nbsp:_
else
	set termguicolors
	set listchars=eol:$,tab:│\ ,tab:›\ ,trail:•,extends:⟩,precedes:⟨,space:·,nbsp:␣
end
set title
set cursorline cursorlineopt=number
set number relativenumber

" themember sets 'background' that reloads colorscheme. We fake it to avoid
" loading dark colorscheme first unconditionally.
let colors_name = 'vivid'

" Get rid of bloat.
let loaded_tutor_mode_plugin = 1

command! -nargs=* Termdebug delcommand Termdebug<bar>packadd termdebug<bar>Termdebug <args>

" Create a command abbrevation.
command! -nargs=+ Ccabbrev let s:_ = [<f-args>][0]|execute(printf("cnoreabbrev <expr> %s getcmdtype() ==# ':' && getcmdpos() ==# %d ? %s : %s", s:_, len(s:_) + 1, <q-args>[len(s:_) + 1:], string(s:_)))

" Sweep out untouched buffers.
command! Sweep call sweep#Sweep()

command! SynShow echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')

command! -bang -nargs=+ Bufdo -tabnew|execute 'bufdo<bang>' <q-args>|bdelete

" Perform shell glob on lines.
command! -nargs=* -range Glob silent! execute ':<line1>,<line2>!while read; do print -l $REPLY/'.escape(<q-args>, '!%').'(N) $REPLY'.escape(<q-args>, '!%').'(N); done'

command! -nargs=1 RegEdit let @<args>=input('"'.<q-args>.'=', @<args>)

command! -nargs=* -complete=command Capture call capture#Capture(<q-args>)

command! -nargs=* -complete=command Time call time#Time(<q-args>)

let s:madhls = ['DiffAdd', 'DiffDelete', 'DiffChange']
let s:modi = 0
command! -nargs=+ Mad call matchadd(s:madhls[s:modi], <q-args>)|let s:modi = (s:modi + 1) % len(s:madhls)

command! -nargs=* DelShada execute 'normal' ':%s/\v^[^ ].*(\n .*){-}\V'.escape(<q-args>, '\/').'\v.*(\n .*)*\n//' "\n"

command! -range URLFilter silent '<,'>!awk '/^http/ {print $1}' | sort -u

command! Ctags !test -d build && ln -sf build/tags tags; ctags -R --exclude=node_modules --exclude='*.json' --exclude='*.patch' '--map-typescript=+.tsx'

inoremap <expr> <C-s> strftime("%F")
inoremap <expr> <C-f> expand("%:t:r")

inoremap <C-r> <C-r><C-o>

" How many times... you little shit...
nnoremap U <nop>

" Copy whole line.
silent! unmap Y

" Handy yanking to system-clipboard.
map gy "+yy

" Reindent before append.
nnoremap <expr> A !empty(getline('.')) ? 'A' : 'cc'

" Clear indent-only line.
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

nnoremap <silent> dar :.argdelete<bar>argument<CR>

" m but show available marks.
nnoremap <expr> m ':echomsg "'.join(map(map(range(char2nr('a'), char2nr('z')) + range(char2nr('A'), char2nr('Z')), {_,nr-> nr2char(nr)}), {_,mark-> (getpos("'".mark)[1] ==# 0 ? mark : ' ')}), '').'"<CR>m'

" Jump to parent indention.
nnoremap <silent> <C-q> :call search('\v^\s+\zs%<'.indent(prevnonblank('.')).'v\S\|^#@!\S', 'b')<CR>

nnoremap <silent> <M-m> :Make<CR>

nnoremap <silent> <M-w> :Bufdo if bufname() !=# ''<bar>update<bar>endif<CR>

nnoremap <silent> <M-q> :quit<CR>

" Put the first line of the paragraph at the top of the window.
nnoremap <silent><expr> z{ '{zt'.(&scrolloff + 1)."\<lt>C-E>"

nnoremap <silent> gp :set paste!<CR>

nnoremap <silent> gss :setlocal spell!<CR>
nnoremap <silent> gse :setlocal spell spelllang=en<CR>
nnoremap <silent> gsh :setlocal spell spelllang=hu<CR>

nnoremap <expr> + (!&diff ? 'g+' : ":diffput\<CR>")
nnoremap <expr> - (!&diff ? 'g-' : ":diffget\<CR>")

nnoremap ! <Cmd>FizzyBuffers<CR>
nmap <C-w>! :split<CR>!

nnoremap g/ <Cmd>FizzyFiles<CR>

nnoremap <silent> <M-o> :buffer #<CR>

nnoremap <expr> <M-!> ':edit '.fnameescape(expand('%:h')).'/<C-z>'

nnoremap <silent><expr> goo ':e %<.'.get({'h': 'c', 'c': 'h', 'hpp': 'cpp', 'cpp': 'hpp'}, expand('%:e'), expand('%:e'))."\<CR>"

nnoremap <C-w>T <C-w>s<C-w>T

nnoremap <expr> s; 'A'.(";:"[&ft == 'python']).'<Esc>'
nnoremap s, A,<Esc>

nnoremap s<C-g> :! stat %<CR>

nnoremap <silent> sw :set wrap!<CR>

nnoremap <silent> sb :execute 'windo let &scrollbind = ' . !&scrollbind<CR>

nnoremap <silent> sp vip:sort /\v^(#!)@!\A*\zs/<CR>

nnoremap Q :normal n.<CR>zz

" Repeat last action over visual block.
xnoremap . :normal! .<CR>

Ccabbrev . '@:'

" Execute macro over visual range
xnoremap <expr><silent> @ printf(':normal! @%s<CR>', getcharstr())

Ccabbrev man 'Man'

Ccabbrev f 'find'.(' ' !=# v:char ? ' ' : '')

" Reindent inner % lines.
nmap >i >%<<$%<<$%
nmap <i <%>>$%>>$%

" Delete surrounding lines.
nmap d< $<%%dd<C-O>dd

" Make {, } linewise.
onoremap <silent> { V{
onoremap <silent> } V}

nmap <silent> z/ <Plug>(FuzzySearchFizzy)

let pets_joker = ''

augroup vimrc_filetypes
	autocmd!
	autocmd FileType xml,html
		\ setlocal equalprg=xmllint\ --encode\ UTF-8\ --html\ --nowrap\ --dropdtd\ --format\ -

	autocmd FileType sh,zsh,dash
		\ setlocal ts=2|
		\ xnoremap <buffer> s< c<<EOF<CR><C-r><C-o>"EOF<CR><Esc><<gvo$B<Esc>i|
		\ nnoremap <silent><buffer><nowait> ]] :call search('^.*\(function\<bar>()\s*{\)', 'W')<CR>|
		\ nnoremap <silent><buffer><nowait> [[ :call search('^.*\(function\<bar>()\s*{\)', 'Wb')<CR>

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
		\ setlocal ts=8 fdm=manual|
		\ setlocal equalprg=clang-format

	autocmd FileType rust
		\ setlocal ts=4 sw=4 fdm=manual

	autocmd FileType json,javascript
		\ setlocal ts=2 suffixesadd+=.js

	autocmd FileType json
		\ setlocal equalprg=jq

	autocmd FileType lua
		\ setlocal ts=2 suffixesadd+=.lua

	autocmd FileType gitcommit,markdown
		\ setlocal spell expandtab ts=2

	let netrw_banner = 0
	let netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+'
	" let netrw_keepdir = 0
	autocmd FileType netrw
		\ nmap <buffer> . -|
		\ nmap <buffer> e :e<Space>
augroup END

augroup vimrc_autoresize
	autocmd! VimResized * wincmd =
augroup END

augroup vimrc_syntax
	autocmd!
	autocmd BufReadPre *.toml ++once packadd vim-toml
	autocmd BufReadPre *.glsl ++once packadd vim-glsl
	autocmd BufReadPre *.zig ++once packadd zig.vim
	autocmd BufReadPre *.rs ++once packadd rust.vim
augroup END
