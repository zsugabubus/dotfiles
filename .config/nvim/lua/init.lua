local o, opt = vim.o, vim.opt

o.autoindent = true
o.autowrite = true
o.copyindent = true
o.cursorline = true
o.cursorlineopt = 'number'
o.expandtab = false
o.fileignorecase = true
o.hidden = true
o.ignorecase = true
o.joinspaces = false -- No double space.
o.lazyredraw = true
o.more = false
o.mouse = ''
o.number = true
o.relativenumber = true
o.scrolloff = 5
o.shiftwidth = 0
o.sidescrolloff = 23
o.smartcase = true
o.splitright = true
o.swapfile = false
o.switchbuf = 'useopen'
o.tab = 8
o.timeoutlen = 600
o.title = true
o.wildcharm = '<C-Z>'
o.wildignorecase = true
o.wildmenu = true
o.wrap = false
opt.cinoptions:append { 't0', ':0', 'l1' }
opt.completeopt = { 'menu', 'longest', 'noselect', 'preview' }
opt.diffopt = { 'filler', 'vertical', 'algorithm:patience' }
opt.matchpairs:append { '‘:’', '“:”' }
opt.nrformats:remove { 'octal' }
opt.path:append { 'src/**', 'include/**' }
opt.shortmess:append 'mrFI'
opt.suffixes:append { '' } -- Rank files lower with no suffix.
opt.wildignore:append { '.git', '*.lock', '*~', 'node_modules' }
opt.wildmode = { 'list:longest', 'full' }

if vim.fn.filewritable(vim.fn.stdpath('config')) then
	o.undofile = true
	o.undodir = vim.fn.stdpath('cache') .. '/undo'
else
	o.undofile = false
	o.shada = 'NONE'
end

o.list = true
o.showbreak = '\\'
if vim.env.TERM == 'linux' then
	opt.listchars = {
		eol = '$',
		tab = '> ',
		trail = '+',
		extends = ':',
		precedes = ':',
		nbsp = '_',
	}
else
	o.termguicolors = true
	opt.listchars = {
		eol = '$',
		tab = '│ ',
		tab = '› ',
		trail = '•',
		extends = '⟩',
		precedes = '⟨',
		space = '·',
		nbsp = '␣',
	}
end

-- themember sets 'background' that reloads colorscheme. We fake it to
-- avoid loading dark colorscheme first unconditionally.
vim.g.colors_name = 'vivid'

-- Disable providers.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

vim.api.nvim_create_autocmd('FocusGained', {
	pattern = '*',
	callback = function()
		local group = vim.api.nvim_create_augroup('init/clipboard', {})
		vim.api.nvim_create_autocmd('TextYankPost', {
			group = group,
			once = true,
			pattern = '*',
			callback = function()
				vim.api.nvim_create_autocmd('FocusLost', {
					group = group,
					pattern = '*',
					callback = function()
						vim.fn.setreg('+', vim.fn.getreg('@'))
					end,
				})
			end,
		})
	end,
})

vim.cmd [=[
command! -nargs=* Termdebug delcommand Termdebug<bar>packadd termdebug<bar>Termdebug <args>

" Create a command abbrevation.
command! -nargs=+ Ccabbrev let s:_ = [<f-args>][0]|execute(printf("cnoreabbrev <expr> %s getcmdtype() ==# ':' && getcmdpos() ==# %d ? %s : %s", s:_, len(s:_) + 1, <q-args>[len(s:_) + 1:], string(s:_)))

command! Sweep silent! %bdelete

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

nnoremap <expr> <M-!> ':edit '.fnameescape(expand('%:h')).'/<C-z>'
nnoremap <silent> <M-m> :Make<CR>
nnoremap <silent> <M-o> :buffer #<CR>
nnoremap <silent> <M-q> :quit<CR>
nnoremap <silent> <M-w> :silent! wa<CR>

" Put the first line of the paragraph at the top of the window.
nnoremap <silent><expr> z{ '{zt'.(&scrolloff + 1)."\<lt>C-E>"

nnoremap <silent> gss :setlocal spell!<CR>
nnoremap <silent> gse :setlocal spell spelllang=en<CR>
nnoremap <silent> gsh :setlocal spell spelllang=hu<CR>

nnoremap <expr> + (!&diff ? 'g+' : ":diffput\<CR>")
nnoremap <expr> - (!&diff ? 'g-' : ":diffget\<CR>")

nnoremap ! <Cmd>FizzyBuffers<CR>
nmap <C-w>! :split<CR>!

nnoremap g/ <Cmd>FizzyFiles<CR>

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

" Execute macro over visual range
xnoremap <expr><silent> @ printf(':normal! @%s<CR>', getcharstr())

Ccabbrev m 'Man'
Ccabbrev man 'Man'

Ccabbrev f 'find'.(' ' !=# v:char ? ' ' : '')

" Reindent inner % lines.
nmap >i >%<<$%<<$%
nmap <i <%>>$%>>$%

vnoremap > >gv
vnoremap < <gv

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
	autocmd BufReadPre *.rs ++once packadd rust.vim
augroup END
]=]

require 'pack'.setup({
	'ansiesc.nvim',
	'cword.nvim',
	'nvim-colorcolors',
	'vim-acid',
	'vim-betterm',
	'vim-bufgrep',
	'vim-difficooler',
	'vim-elephant',
	'vim-fizzy',
	'vim-fuzzysearch',
	'vim-git',
	'vim-japan',
	'vim-make',
	'vim-mall',
	'vim-mankey',
	'vim-newfile',
	'vim-pastereindent',
	'vim-pets',
	'vim-qf',
	'vim-star',
	'vim-stdin',
	'vim-surround',
	'vim-textobjects',
	'vim-themember',
	'vim-tilde',
	'vim-vnicode',
	'vim-woman',
	'vim-wtc7',
	'vim-wtf',
	'vimdent.nvim',
}, {
	source_blacklist = {
		'/runtime/plugin/netrwPlugin.vim',
		'/runtime/plugin/rplugin.vim',
		'/runtime/plugin/tohtml.vim',
		'/runtime/plugin/tutor.vim',
		'/vimfiles/plugin/black.vim',
		'/vimfiles/plugin/fzf.vim',
	},
})
