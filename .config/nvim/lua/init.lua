local o, opt = vim.o, vim.opt
local api, cmd, fn = vim.api, vim.cmd, vim.fn
local group = api.nvim_create_augroup('init', {})

local function map(mode, lhs, rhs)
	return api.nvim_set_keymap(mode, lhs, rhs, {
		noremap = true,
	})
end

local function remap(mode, lhs, rhs)
	return api.nvim_set_keymap(mode, lhs, rhs, {
		noremap = false,
	})
end

local function smap(mode, lhs, rhs)
	return api.nvim_set_keymap(mode, lhs, rhs, {
		silent = true,
	})
end

local function fmap(mode, lhs, callback)
	return api.nvim_set_keymap(mode, lhs, '', {
		callback = callback,
	})
end

local function xmap(mode, lhs, callback)
	return api.nvim_set_keymap(mode, lhs, '', {
		expr = true,
		replace_keycodes = true,
		callback = callback,
	})
end

local function xmapescape(s)
	return string.gsub(s, '<', '<LT>')
end

local function filetype(pattern, callback)
	return api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = pattern,
		callback = callback,
	})
end

local function cabbr(lhs, rhs)
	vim.cmd.cnoreabbrev(
		'<expr>',
		lhs,
		string.format(
			"getcmdtype() ==# ':' && getcmdpos() ==# %d ? %s : %s",
			#lhs + 1,
			fn.string(rhs),
			fn.string(lhs)
		)
	)
end

function _G.tabline()
	return require('init.tabline')()
end

o.autoindent = true
o.autowrite = true
o.copyindent = true
o.cursorline = true
o.cursorlineopt = 'number'
o.expandtab = false
o.fileignorecase = true
o.foldopen = true
o.grepformat = '%f:%l:%c:%m'
o.grepprg = 'noglob rg --vimgrep --smart-case'
o.hidden = true
o.ignorecase = true
o.joinspaces = false -- No double space.
o.laststatus = 2
o.lazyredraw = true
o.more = false
o.mouse = ''
o.number = true
o.relativenumber = true
o.scrolloff = 5
o.shiftwidth = 0
o.showmode = false
o.sidescrolloff = 23
o.smartcase = true
o.splitright = true
o.swapfile = false
o.switchbuf = 'useopen'
o.tabline = '%!v:lua.tabline()'
o.timeoutlen = 600
o.title = true
o.wildcharm = '<C-Z>'
o.wildignorecase = true
o.wildmenu = true
o.wrap = false
opt.cinoptions:append({ 't0', ':0', 'l1' })
opt.completeopt = { 'menu', 'longest', 'noselect', 'preview' }
opt.diffopt = { 'closeoff', 'filler', 'vertical', 'algorithm:patience' }
opt.matchpairs:append({ '‘:’', '“:”' })
opt.nrformats:remove({ 'octal' })
opt.path:append({ 'src/**', 'include/**' })
opt.shortmess:append('mrFI')
opt.suffixes:append({ '' }) -- Rank files lower with no suffix.
opt.wildignore:append({ '.git', '*.lock', '*~', 'node_modules' })
opt.wildmode = { 'list:longest', 'full' }

if fn.filewritable(fn.stdpath('config')) then
	o.undofile = true
	o.undodir = fn.stdpath('cache') .. '/undo'
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

do
	local theme_file = fn.stdpath('config') .. '/theme.vim'

	local function load_theme()
		-- Avoid loading colorscheme twice.
		vim.g.colors_name = nil
		pcall(cmd.source, theme_file)
		cmd.colorscheme('vivid')
	end

	api.nvim_create_autocmd('Signal', {
		group = group,
		pattern = 'SIGUSR1',
		callback = function()
			load_theme()
			cmd.redraw({ bang = true })
		end,
	})

	load_theme()
end

map('c', '<C-a>', '<Home>')
map('c', '<C-b>', '<Left>')
map('c', '<C-e>', '<End>')
map('c', '<C-f>', '<Right>')
map('c', '<C-n>', '<Down>')
map('c', '<C-p>', '<Up>')
map('c', '<C-v>', '<C-f>')
map('c', '<M-b>', '<C-Left>')
map('c', '<M-f>', '<C-Right>')

map('i', '<C-a>', '<C-o>_')
map('i', '<C-e>', '<C-o>g_<Right>')

smap('n', '<M-l>', ':lnext<CR>:silent! normal! zOzz<CR>')
smap('n', '<M-L>', ':lprev<CR>:silent! normal! zOzz<CR>')
smap('n', '<M-n>', ':cnext<CR>:silent! normal! zOzz<CR>')
smap('n', '<M-N>', ':cprev<CR>:silent! normal! zOzz<CR>')
smap('n', '<M-f>', ':next<CR>')
smap('n', '<M-F>', ':prev<CR>')

xmap('i', '<C-f>', function()
	local s = fn.expand('%:t:r')
	if s == 'init' or s == 'index' or s == 'main' then
		s = fn.expand('%:p:h:t')
	end
	return xmapescape(s)
end)

map('i', '<C-r>', '<C-r><C-o>')

map('n', 'U', '')

-- Reindent before append.
xmap('n', 'A', function()
	return api.nvim_get_current_line() ~= '' and 'A' or 'cc'
end)

smap('n', 'dar', ':.argdelete<bar>argument<CR>')

-- Jump to parent indention.
fmap('n', '<C-q>', function()
	fn.search(
		[[\v^\s+\zs%<]] .. fn.indent(fn.prevnonblank('.')) .. [[v\S|^#@!\S]],
		'b'
	)
end)

xmap('n', '<M-!>', function()
	return ':edit ' .. xmapescape(fn.fnameescape(fn.expand('%:h'))) .. '/<C-Z>'
end)
smap('n', '<M-m>', ':Make<CR>')
smap('n', '<M-o>', ':buffer #<CR>')
smap('n', '<M-q>', ':quit<CR>')
smap('n', '<M-w>', ':silent! wa<CR>')

-- Put the first line of the paragraph at the top of the window.
xmap('n', 'z{', function()
	return '{zt' .. (vim.o.scrolloff + 1) .. '<C-E>'
end)

smap('n', 'gss', ':setlocal spell!<CR>')
smap('n', 'gse', ':setlocal spell spelllang=en<CR>')
smap('n', 'gsh', ':setlocal spell spelllang=hu<CR>')

map('n', '+', 'g+')
map('n', '-', 'g-')

map('n', '!', '<Cmd>FizzyBuffers<CR>')
map('n', 'g/', '<Cmd>FizzyFiles<CR>')

map('n', '<C-w>T', '<C-w>s<C-w>T')

xmap('n', 's;', function()
	return 'A' .. (vim.o.filetype == 'python' and ':' or ';') .. '<Esc>'
end)
map('n', 's,', 'A,<Esc>')

map('n', 's<C-g>', ':! stat %<CR>')

fmap('n', 'sb', function()
	local x = not vim.wo.scrollbind
	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		vim.wo[win].scrollbind = x
	end
end)
smap('n', 'sp', [[vip:sort /\v^(#!)@!\A*\zs/<CR>]])
smap('n', 'sw', ':set wrap!<CR>')

map('n', 'Q', ':normal n.<CR>zz')

-- Repeat over visual block
map('x', '.', ':normal! .<CR>')

-- Execute macro over visual range
xmap('x', '@', function()
	return string.format(':normal! @%s<CR>', fn.getcharstr())
end)

-- Reindent inner % lines.
remap('n', '>i', '>%<<$%<<$%')
remap('n', '<i', '<%>>$%>>$%')

map('v', '>', '>gv')
map('v', '<', '<gv')

-- Linewise {, }.
map('o', '{', 'V{')
map('o', '}', 'V}')

map('n', 'z/', '<Plug>(FuzzySearchFizzy)')

map('x', '//', 'y:GREP -F <C-r>=shellescape(@", 1)<CR><CR>')

cabbr('ccd', 'cd %:p:h<C-Z>')
cabbr('lcd', 'lcd %:p:h<C-Z>')
cabbr('tcd', 'tcd %:p:h<C-Z>')

cabbr('bg', 'BufGrep')
cabbr('g', 'GREP')
cabbr('gr', 'GREP')

cabbr('m', 'Man')
cabbr('man', 'Man')

api.nvim_create_user_command('Capture', function(opts)
	if opts.args == '' then
		opts.args = 'messages'
	end
	cmd.edit(fn.fnameescape('output://' .. opts.args))
end, {
	complete = 'command',
	nargs = '*',
})

api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'output://*',
	callback = function(opts)
		local src = string.sub(opts.match, 10)
		local output = api.nvim_exec2(src, {
			output = true,
		}).output
		api.nvim_buf_set_lines(opts.buf, 0, -1, false, vim.split(output, '\n'))
		local bo = vim.bo[opts.buf]
		bo.buftype = 'nofile'
		bo.readonly = true
		bo.swapfile = false
	end,
})

api.nvim_create_user_command('Sweep', function()
	for _, buf in ipairs(api.nvim_list_bufs()) do
		if fn.bufwinid(buf) == -1 then
			pcall(api.nvim_buf_call, buf, cmd.bdelete)
		end
	end
end, {})

api.nvim_create_user_command('GREP', function(opts)
	if opts.args == '' then
		opts.args = fn.getreg('/')
	end

	local DO_NOT_QUOTE_RE = vim.regex([=[\v\c(^| )-[a-z-]|^['"]]=])

	cmd.grep(
		DO_NOT_QUOTE_RE:match_str(opts.args) and opts.args
			or fn.shellescape(opts.args, 1)
	)
	cmd.redraw()
end, { nargs = '*' })

api.nvim_create_user_command('TODO', 'GREP \\b(TODO|FIXME|BUG|WTF)[: ]', {})

api.nvim_create_autocmd({ 'FocusGained', 'VimEnter' }, {
	group = group,
	pattern = '*',
	callback = function()
		local group = api.nvim_create_augroup('init/clipboard', {})
		api.nvim_create_autocmd('TextYankPost', {
			group = group,
			once = true,
			pattern = '*',
			callback = function()
				api.nvim_create_autocmd('FocusLost', {
					group = group,
					pattern = '*',
					callback = function()
						fn.setreg('+', fn.getreg('@'))
					end,
				})
			end,
		})
	end,
})

do
	local colors_dir = fn.stdpath('config') .. '/colors'

	api.nvim_create_autocmd('BufWritePost', {
		group = group,
		pattern = '*.vim,*.lua',
		nested = true,
		callback = function(opts)
			local dir = fn.fnamemodify(opts.file, ':p:h')
			if dir == colors_dir then
				cmd.colorscheme(fn.fnamemodify(opts.file, ':t:r'))
			end
		end,
	})
end

api.nvim_create_autocmd('BufNewFile', {
	group = group,
	pattern = '*',
	callback = function()
		local function once(event, callback)
			return api.nvim_create_autocmd(event, {
				group = group,
				buffer = 0,
				once = true,
				callback = callback,
			})
		end

		once('FileType', function()
			if fn.changenr() ~= 0 or not vim.bo.modifiable then
				return
			end

			local ft = vim.bo.filetype
			local interpreter = ({
				javascript = 'node',
				python = 'python3',
			})[ft] or ft

			local path = fn.exepath(interpreter)
			if path == '' then
				return
			end

			api.nvim_buf_set_lines(0, 0, -1, false, {
				'#!' .. path,
				'',
			})
			cmd.normal({ args = { 'G' }, bang = true })
		end)

		once('BufWritePre', function(opts)
			fn.mkdir(vim.fs.dirname(opts.file), 'p')
		end)

		once('BufWritePost', function(opts)
			if string.sub(fn.getline(1), 1, 2) == '#!' then
				local uv = vim.loop
				local bit = require('bit')
				local mode = uv.fs_stat(opts.file).mode
				local ugo_x = tonumber('111', 8)
				uv.fs_chmod(opts.file, bit.bor(mode, ugo_x))
			end
		end)
	end,
})

vim.filetype.add({
	pattern = {
		['/tmp/fstab%.'] = 'fstab',
	},
})

filetype(
	'vim,lua,yaml,css,stylus,xml,php,html,pug,gdb,vue,meson,*script*,*sh,json',
	function()
		vim.bo.tabstop = 2
	end
)

filetype('awk,python,rust', function()
	vim.bo.tabstop = 4
end)

filetype('gitcommit,markdown', function()
	vim.wo.spell = true
end)

filetype('json', function()
	vim.bo.equalprg = 'jq'
end)

filetype('xml,html', function()
	vim.bo.equalprg =
		'xmllint --encode UTF-8 --html --nowrap --dropdtd --format -'
end)

-- vim.treesitter pulls in lot's of Lua code.
api.nvim_create_autocmd('FileType', {
	group = group,
	pattern = 'typescriptreact',
	once = true,
	callback = function()
		vim.treesitter.language.register('tsx', 'typescriptreact')
	end,
})

api.nvim_create_autocmd('TextChanged', {
	group = group,
	pattern = '*',
	callback = function()
		if vim.wo.diff then
			cmd.diffupdate()
		end
	end,
})

api.nvim_create_autocmd('BufHidden,BufUnload', {
	group = group,
	pattern = '*',
	callback = function()
		if not vim.bo.buflisted then
			cmd.diffoff({ bang = true })
		end
	end,
})

api.nvim_create_autocmd('VimResized', {
	group = group,
	callback = function()
		cmd.wincmd('=')
	end,
})

api.nvim_create_autocmd('StdinReadPost', {
	group = group,
	pattern = '*',
	callback = function()
		vim.bo.buftype = 'nofile'
		vim.bo.bufhidden = 'hide'
		vim.bo.swapfile = false
	end,
})

api.nvim_create_autocmd('BufReadPost', {
	group = group,
	pattern = '*',
	callback = function()
		local IGNORE_RE = vim.regex([[\vgit|mail]])

		api.nvim_create_autocmd('FileType', {
			group = group,
			buffer = 0,
			once = true,
			callback = function()
				if IGNORE_RE:match_str(vim.bo.filetype) then
					return
				end

				api.nvim_create_autocmd('BufEnter', {
					group = group,
					buffer = 0,
					once = true,
					callback = function()
						local lnum = fn.line('\'"')
						if 1 <= lnum and lnum <= fn.line('$') then
							cmd.normal({ args = { 'g`"zvzz' }, bang = true })
						end
					end,
				})
			end,
		})
	end,
})

api.nvim_create_autocmd('VimLeave', {
	group = group,
	pattern = '*',
	callback = function()
		if vim.v.dying == 0 and vim.v.exiting == 0 and vim.v.this_session ~= '' then
			cmd.mkession({ args = { vim.v.this_session }, bang = true })
		end
	end,
})

api.nvim_create_user_command('SourceSession', function()
	cmd.source('Session.vim')
end, {})

do
	local IGNORE_WHITESPACE_RE =
		vim.regex([[\v^(|text|markdown|mail)$|git|diff|log]])

	api.nvim_create_autocmd('FileType,BufWinEnter,WinNew,ColorScheme', {
		group = group,
		pattern = '*',
		callback = function()
			api.nvim_set_hl(0, 'WhitespaceError', {
				default = true,
				ctermbg = 197,
				ctermfg = 231,
				bg = '#ff005f',
				fg = '#ffffff',
			})
		end,
	})

	api.nvim_create_autocmd('FileType,BufWinEnter,WinNew', {
		group = group,
		pattern = '*',
		callback = function()
			if vim.w.japan then
				fn.matchdelete(vim.w.japan)
				vim.w.japan = nil
			end
			if
				vim.bo.buftype == ''
				and not vim.bo.readonly
				and vim.bo.modifiable
				and not IGNORE_WHITESPACE_RE:match_str(vim.bo.filetype)
			then
				vim.w.japan = fn.matchadd('WhitespaceError', [[\v +\t+|\s+%#@!$]], 10)
			end
		end,
	})
end

api.nvim_create_user_command(
	'Japan',
	[[keepjumps keeppatterns lockmarks silent %s/\m\s\+$//e]],
	{}
)

map('t', '<C-v>', '<C-\\><C-n>')

api.nvim_create_autocmd('TermClose', {
	group = group,
	callback = function()
		cmd.stopinsert()
	end,
})

api.nvim_create_user_command('Register', function(opts)
	cmd.edit(fn.fnameescape('reg://' .. opts.args))
end, {
	nargs = '?',
})

api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'reg://*',
	callback = function(opts)
		local regname = string.sub(opts.match, 7)
		api.nvim_buf_set_lines(opts.buf, 0, -1, true, fn.getreg(regname, 1, true))
	end,
})

api.nvim_create_autocmd('BufWriteCmd', {
	group = group,
	pattern = 'reg://*',
	callback = function(opts)
		local regname = string.sub(opts.match, 7)
		fn.setreg(regname, api.nvim_buf_get_lines(opts.buf, 0, -1, true))
		vim.bo[opts.buf].modified = false
		api.nvim_echo({
			{
				string.format('Register %s written', regname),
				'Normal',
			},
		}, true, {})
	end,
})

api.nvim_create_autocmd('FocusLost', {
	group = group,
	pattern = '*',
	callback = function()
		pcall(fn.writefile, { fn.expand('%:p') }, fn.stdpath('run') .. '/nvim_here')
	end,
})

-- Disable providers.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

require('pack').setup({
	{ 'tmux.nvim' },
	{ 'ansiesc.nvim' },
	{ 'cword.nvim' },
	{ 'nvim-colorcolors' },
	{ 'vim-bufgrep' },
	{ 'vim-fizzy' },
	{ 'vim-fuzzysearch' },
	{ 'git.nvim' },
	{ 'vim-make' },
	{ 'vim-mankey' },
	{ 'vim-pastereindent' },
	{ 'vim-pets' },
	{ 'vim-qf' },
	{ 'vim-star' },
	{
		'vim-surround',
		before = function()
			map('n', 'ds', '<Plug>(SurroundDelete)')
			map('x', 's', '<Plug>(Surround)')
		end,
	},
	{ 'vim-textobjects' },
	{ 'vim-tilde' },
	{ 'vim-vnicode' },
	{ 'vim-woman' },
	{ 'vim-wtf' },
	{ 'vimdent.nvim' },
	{
		'commenter.nvim',
		after = function()
			map('n', 'gc', '<Plug>(commenter)')
			map('n', 'gcc', '<Plug>(commenter-current-line)')
		end,
	},
	{
		'jumpmotion.nvim',
		after = function()
			map('', '<space>', '<Plug>(jumpmotion)')
		end,
	},
	{
		'nvim-treesitter',
		enabled = false,
		after = function(self)
			require('nvim-treesitter.configs').setup({
				indent = { enable = false },
				highlight = { enable = false },
				parser_install_dir = fn.stdpath('data') .. '/site',
			})
		end,
	},
}, {
	source_blacklist = {
		'/runtime/plugin/health.vim',
		'/runtime/plugin/netrwPlugin.vim',
		'/runtime/plugin/rplugin.vim',
		'/runtime/plugin/spellfile.vim',
		'/runtime/plugin/tohtml.vim',
		'/runtime/plugin/tutor.vim',
		'/vimfiles/plugin/black.vim',
		'/vimfiles/plugin/fzf.vim',
	},
})

require('init.statusline')
