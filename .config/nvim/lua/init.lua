local function make_o()
	local OPTS = {}

	local get = vim.api.nvim_get_option_value
	local set = vim.api.nvim_set_option_value

	return setmetatable({}, {
		__index = function(_, k)
			return get(k, OPTS)
		end,
		__newindex = function(_, k, v)
			return set(k, v, OPTS)
		end,
	})
end

local function make_bo()
	local OPTS = { buf = 0 }

	local type = type
	local setmetatable = setmetatable
	local rawget = rawget
	local rawset = rawset
	local get = vim.api.nvim_get_option_value
	local set = vim.api.nvim_set_option_value

	local mt = {
		__index = function(t, k)
			return get(k, rawget(t, OPTS))
		end,
		__newindex = function(t, k, v)
			return set(k, v, rawget(t, OPTS))
		end,
	}

	return setmetatable({}, {
		__mode = 'kv',
		__index = function(t, k)
			if type(k) == 'string' then
				return get(k, OPTS)
			end
			local o = setmetatable({ [OPTS] = { buf = k } }, mt)
			rawset(t, k, o)
			return o
		end,
		__newindex = function(_, k, v)
			return set(k, v, OPTS)
		end,
	})
end

local function make_wo()
	local OPTS = { win = 0 }

	local type = type
	local setmetatable = setmetatable
	local rawget = rawget
	local rawset = rawset
	local get = vim.api.nvim_get_option_value
	local set = vim.api.nvim_set_option_value

	local mt = {
		__index = function(t, k)
			return get(k, rawget(t, OPTS))
		end,
		__newindex = function(t, k, v)
			return set(k, v, rawget(t, OPTS))
		end,
	}

	return setmetatable({}, {
		__mode = 'kv',
		__index = function(t, k)
			if type(k) == 'string' then
				return get(k, OPTS)
			end
			local o = setmetatable({
				[OPTS] = { win = k },
				[0] = setmetatable({ [OPTS] = { win = k, scope = 'local' } }, mt),
			}, mt)
			rawset(t, k, o)
			return o
		end,
		__newindex = function(_, k, v)
			return set(k, v, OPTS)
		end,
	})
end

vim.o = make_o()
vim.bo = make_bo()
vim.wo = make_wo()

local api = vim.api
local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn
local o = vim.o
local wo = vim.wo

local autocmd = api.nvim_create_autocmd
local keymap = api.nvim_set_keymap
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('init', {})

local MAP_OPTS = { noremap = true }
local function map(mode, lhs, rhs)
	return keymap(mode, lhs, rhs, MAP_OPTS)
end

local function nxo_map(lhs, rhs)
	map('n', lhs, rhs)
	map('x', lhs, rhs)
	map('o', lhs, rhs)
end

local REMAP_OPTS = {}
local function remap(mode, lhs, rhs)
	return keymap(mode, lhs, rhs, REMAP_OPTS)
end

local SMAP_OPTS = { silent = true }
local function smap(mode, lhs, rhs)
	return keymap(mode, lhs, rhs, SMAP_OPTS)
end

local function fmap(mode, lhs, callback)
	return keymap(mode, lhs, '', { callback = callback })
end

local function xmap(mode, lhs, callback)
	return keymap(mode, lhs, '', {
		expr = true,
		replace_keycodes = true,
		callback = callback,
	})
end

local function xmapescape(s)
	return string.gsub(s, '<', '<LT>')
end

local function filetype(pattern, callback)
	return autocmd('FileType', {
		group = group,
		pattern = pattern,
		callback = callback,
	})
end

local function cabbr(lhs, rhs)
	cmd.cnoreabbrev(
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
o.cinoptions = 't0,:0,l1'
o.completeopt = 'menu,longest,noselect,preview'
o.copyindent = true
o.cursorline = true
o.cursorlineopt = 'number'
o.diffopt = 'closeoff,filler,vertical,algorithm:patience'
o.expandtab = false
o.fileignorecase = true
o.foldopen = ''
o.grepformat = '%f:%l:%c:%m'
o.grepprg = 'noglob rg --vimgrep --smart-case'
o.hidden = true
o.ignorecase = true
o.joinspaces = false -- No double space.
o.laststatus = 2
o.lazyredraw = true
o.modelines = 1
o.more = false
o.mouse = ''
o.number = true
o.relativenumber = true
o.scrolloff = 5
o.shiftwidth = 0
o.shortmess = o.shortmess .. 'mrFI'
o.showmode = false
o.sidescrolloff = 23
o.smartcase = true
o.splitright = true
o.swapfile = false
o.switchbuf = ''
o.tabline = '%!v:lua.tabline()'
o.timeoutlen = 600
o.title = true
o.wildignore = '.git,*.lock,*~,node_modules'
o.wildignorecase = true
o.wildmenu = true
o.wildmode = 'list:longest,full'
o.wrap = false

if fn.filewritable(fn.stdpath('config')) == 2 then
	o.undofile = true
	o.undodir = fn.stdpath('cache') .. '/undo'
else
	o.undofile = false
	o.shadafile = 'NONE'
end

o.list = true
o.showbreak = '\\'
if vim.env.TERM == 'linux' then
	o.listchars = 'eol:$,tab:> ,trail:+,extends::,precedes::,nbsp:_'
else
	o.termguicolors = true
	o.listchars =
		'eol:$,tab:› ,trail:•,extends:⟩,precedes:⟨,nbsp:␣,space:·'
end

do
	local theme_file = fn.stdpath('config') .. '/theme.vim'

	local function reload()
		-- Avoid loading colorscheme twice.
		vim.g.colors_name = nil
		pcall(cmd.source, theme_file)
		cmd.colorscheme('vivid')
	end

	autocmd('Signal', {
		group = group,
		pattern = 'SIGUSR1',
		nested = true,
		callback = function()
			reload()
			cmd.redraw({ bang = true })
		end,
	})

	reload()
end

do
	local function set_terminal_color(i, color)
		vim.g['terminal_color_' .. i] = color
	end

	local function set_terminal_palette(palette)
		for i = 1, 16 do
			set_terminal_color(i - 1, palette[i] or palette[i - 8])
		end
	end

	local function update()
		set_terminal_palette(vim.go.background == 'light' and {
			'#080808',
			'#ff0000',
			'#00af00',
			'#ff8f00',
			'#0087ff',
			'#af00d7',
			'#00d7ff',
			'#949494',
		} or {
			'#080808',
			'#ff1010',
			'#00d700',
			'#ff8f00',
			'#0087ff',
			'#af00d7',
			'#00ffff',
			'#c6c6c6',
		})
	end

	autocmd('OptionSet', {
		group = group,
		pattern = 'background',
		callback = function()
			update()
		end,
	})

	update()
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
smap('n', '<M-n>', ':Cnext<CR>:silent! normal! zOzz<CR>')
smap('n', '<M-N>', ':Cprev<CR>:silent! normal! zOzz<CR>')
smap('n', '<M-f>', ':next<CR>')
smap('n', '<M-F>', ':prev<CR>')
smap('n', '<M-j>', ':wincmd W<CR>')
smap('n', '<M-k>', ':wincmd w<CR>')
smap('n', '<M-o>', ':buffer #<CR>')
smap('n', '<Tab>', ':wincmd p<CR>')

smap('n', ']q', ':Cnewer<CR>')
smap('n', '[q', ':Colder<CR>')

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
	return fn.col('$') > 1 and 'A' or 'cc'
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
	local s = string.match(fn.expand('%'), '^(.*/)[^/]') or './'
	return string.format(':edit %s<C-Z>', xmapescape(fn.fnameescape(s)))
end)
smap('n', '<M-q>', ':quit<CR>')
smap('n', '<M-w>', ':silent! wa<CR>')

-- Put the first line of the paragraph at the top of the window.
xmap('n', 'z{', function()
	return '{zt' .. (o.scrolloff + 1) .. '<C-E>'
end)

smap('n', 'gss', ':setlocal spell!<CR>')
smap('n', 'gse', ':setlocal spell spelllang=en<CR>')
smap('n', 'gsh', ':setlocal spell spelllang=hu<CR>')

map('n', '+', 'g+')
map('n', '-', 'g-')

smap('n', '<C-w>T', ':tab split<CR>')
map('n', '<C-w>d', ':windo diffthis<CR>')

xmap('n', 's;', function()
	return 'A' .. (o.filetype == 'python' and ':' or ';') .. '<Esc>'
end)
map('n', 's,', 'A,<Esc>')

map('n', 's<C-g>', ':! stat %<CR>')

fmap('n', 'sb', function()
	local x = not wo.scrollbind
	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		wo[win][0].scrollbind = x
	end
end)
smap('n', 'sp', [[vip:sort /\v^(#!)@!\A*\zs/<CR>]])
smap('n', 'sq', ':Qread<CR>')
smap('n', 'sq', ':Qf<CR>')
smap('n', 'sQ', ':tabnew|Qe<CR>')
map('n', 'su', ':Undotree<CR>:view<CR>')
map('n', 'ss', ':%s//g<Left><Left>')
remap('n', 's/', 'ss/')
map('v', 'ss', ':s//g<Left><Left>')
remap('v', 's/', 'ss/')
smap('n', 'sw', ':set wrap!<CR>')
smap('n', 'se', ':edit<CR>')
smap('n', 's<space>', ':nmap <lt>buffer> <lt>space> <lt>C-d><CR>')

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

map('x', '>', '>gv')
map('x', '<', '<gv')

-- Linewise {, }.
map('o', '{', 'V{')
map('o', '}', 'V}')

map('n', 'gr', ':GREP ')
map('n', 'gw', ':GREP -swF <C-r>=shellescape(expand("<cword>"))<CR><CR>')
map('x', '//', 'y:GREP -F <C-r>=shellescape(@", 1)<CR><CR>')
remap('x', 'gr', '//')

cabbr('ccd', 'cd %:p:h<C-Z>')
cabbr('lcd', 'lcd %:p:h<C-Z>')
cabbr('tcd', 'tcd %:p:h<C-Z>')

cabbr('bg', 'BufGrep')
cabbr('hg', 'helpgrep')
cabbr('g', 'GREP')
cabbr('gr', 'GREP')

cabbr('m', 'Man')
cabbr('man', 'Man')

user_command('Sweep', function()
	for _, buf in ipairs(api.nvim_list_bufs()) do
		if fn.bufwinid(buf) == -1 then
			pcall(api.nvim_buf_call, buf, cmd.bdelete)
		end
	end
end, {})

user_command('Changes', function()
	local buf = api.nvim_get_current_buf()
	local change_list = fn.getchangelist(buf)
	fn.setloclist(
		0,
		vim.tbl_map(function(v)
			v.bufnr = buf
			v.text = api.nvim_buf_get_lines(buf, v.lnum - 1, v.lnum, true)[1]
			return v
		end, change_list[1])
	)
	cmd.lopen()
	cmd.lfirst({ count = change_list[2] })
end, {})

user_command('GREP', function(opts)
	local DO_NOT_QUOTE_RE = vim.regex([=[\v\c(^| )-[a-z-]|^['"]]=])

	cmd.grep(
		DO_NOT_QUOTE_RE:match_str(opts.args) and opts.args
			or fn.shellescape(opts.args, 1)
	)
	cmd.redraw()
end, { nargs = '+' })

user_command('TODO', 'GREP \\b(TODO|FIXME|BUG|WTF)[: ]', {})

user_command('Gconflicts', 'GREP ^<<<<<<<', {})

user_command('Glob', function(opts)
	local base = 'read! rg --files --sort=path'
	if opts.args == '' then
		cmd(base)
	else
		cmd(string.format('%s -g %s', base, fn.shellescape(opts.args)))
	end
end, { nargs = '*' })

do
	local buf

	user_command('Qread', function(opts)
		if not buf or opts.bang then
			if api.nvim_buf_get_name(0) == '' then
				cmd.edit('tmux://pane/{last}')
			end
			buf = api.nvim_get_current_buf()
		end

		api.nvim_echo({
			{
				string.format('%s qread', vim.inspect(api.nvim_buf_get_name(buf))),
				'Normal',
			},
		}, false, {})

		api.nvim_buf_call(buf, function()
			cmd.edit()

			local saved = bo.errorformat
			bo.errorformat = table.concat({
				-- rust
				'%Eerror[E%n]: %m',
				'%Eerror: %m',
				'%Wwarning: %m',
				'%Nnote: %m',
				'%C%*[ ]--> %f:%l:%c',
				-- flake8
				'%f:%l:%c: %m',
				-- pytest
				'%f:%l: %m',
				-- vitest
				'\\ FILE  %f:%l:%c',
				-- git status
				'\\        %m:   %f',
			}, ',')

			cmd.Cgetbuffer()

			bo.errorformat = saved
		end)

		cmd.Cnext()
	end, { bang = true })
end

autocmd({ 'FocusGained', 'VimEnter' }, {
	group = group,
	callback = function()
		local group = api.nvim_create_augroup('init/clipboard', {})
		autocmd('TextYankPost', {
			group = group,
			once = true,
			callback = function()
				autocmd('FocusLost', {
					group = group,
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

	autocmd('BufWritePost', {
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

autocmd('BufNewFile', {
	group = group,
	callback = function()
		local function once(event, callback)
			autocmd(event, {
				group = group,
				buffer = 0,
				once = true,
				callback = callback,
			})
		end

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
		['.*'] = {
			function(path, bufnr)
				local content = api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
				if string.match(content, '^[* ]*%x%x%x%x%x%x') then
					return 'git'
				end
				if string.match(content, '^%-+BEGIN.*PRIVATE KEY') then
					return 'privatekey',
						function()
							vim.schedule(function()
								cmd('silent keeppattern normal! zE2GV/^-/-1\rzf')
							end)
						end
				end
			end,
			{ priority = -math.huge },
		},
	},
})

filetype('lua,help', function()
	vim.treesitter.stop()
end)

filetype(
	'vim,lua,yaml,css,stylus,xml,php,html,pug,gdb,vue,meson,*script*,*sh,json,jsonc',
	function()
		bo.tabstop = 2
	end
)

filetype('awk,python,rust', function()
	bo.tabstop = 4
end)

filetype('gitcommit,markdown', function()
	api.nvim_set_option_value('spell', true, { scope = 'local' })
end)

filetype('json', function()
	bo.equalprg = 'jq'
end)

filetype('xml,html', function()
	bo.equalprg = 'xmllint --encode UTF-8 --html --nowrap --dropdtd --format -'
end)

filetype('directory', function()
	local keymap = api.nvim_buf_set_keymap
	keymap(0, 'n', 'gu', '<Plug>(explorer-goto-parent)', SMAP_OPTS)
	keymap(0, 'n', 'g.', '<Plug>(explorer-cd)', SMAP_OPTS)
	keymap(0, 'n', '<CR>', 'Vgf', SMAP_OPTS)
end)

filetype('cucumber', function()
	cmd.Varign()
end)

-- vim.treesitter pulls in lot's of Lua code.
autocmd('FileType', {
	group = group,
	pattern = 'typescriptreact',
	once = true,
	callback = function()
		vim.treesitter.language.register('tsx', 'typescriptreact')
	end,
})

autocmd('TextChanged', {
	group = group,
	callback = function()
		if wo.diff then
			cmd.diffupdate()
		end
	end,
})

autocmd({ 'BufHidden', 'BufUnload' }, {
	group = group,
	callback = function()
		if not bo.buflisted then
			cmd.diffoff({ bang = true })
		end
	end,
})

autocmd('VimResized', {
	group = group,
	callback = function()
		cmd.wincmd('=')
	end,
})

autocmd('StdinReadPost', {
	group = group,
	callback = function()
		bo.buftype = 'nofile'
		bo.bufhidden = 'hide'
		bo.swapfile = false
	end,
})

autocmd('BufReadPost', {
	group = group,
	callback = function()
		local IGNORE_RE = vim.regex([[\vgit|mail]])

		autocmd('FileType', {
			group = group,
			buffer = 0,
			once = true,
			callback = function()
				if IGNORE_RE:match_str(bo.filetype) then
					return
				end

				autocmd('BufEnter', {
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

autocmd('VimLeave', {
	group = group,
	callback = function()
		if vim.v.dying == 0 and vim.v.exiting == 0 and vim.v.this_session ~= '' then
			cmd.mkession({ args = { vim.v.this_session }, bang = true })
		end
	end,
})

user_command('SourceSession', function()
	cmd.source('Session.vim')
end, {})

user_command(
	'Japan',
	[[keepjumps keeppatterns lockmarks silent %s/\m\s\+$//e]],
	{}
)

map('t', '<C-v>', '<C-\\><C-n>')

autocmd('TermClose', {
	group = group,
	callback = function()
		cmd.stopinsert()
	end,
})

autocmd('FocusLost', {
	group = group,
	callback = function(opts)
		if bo[opts.buf].buftype == '' then
			pcall(
				fn.writefile,
				{ fn.expand('%:p') },
				fn.stdpath('run') .. '/nvim_here'
			)
		end
	end,
})

user_command('Rm', '! rm %', {})

user_command(
	'Cut',
	[[execute '<line1>,<line2>!cut -f'.join([1, <f-args>], ',')]],
	{ nargs = '*', range = '%' }
)

user_command(
	'Csv',
	[[set buftype=nowrite|silent keeppattern %s/\v("[^"]*"|[^",]*),/\1\t/g|Varign]],
	{}
)

fmap('n', 'cd', function()
	cmd.cd(vim.fn.expand('%:p' .. string.rep(':h', vim.v.count1)))
end)

map('n', 'c-', ':cd -<CR>')

require('pack').setup({
	{
		'align.nvim',
		after = function()
			nxo_map('gl', '<Plug>(align)')
			remap('n', 'gL', 'viigl|')
		end,
	},
	{ 'ansiesc.nvim' },
	{ 'archive.nvim' },
	{
		'arglist.nvim',
		after = function()
			map('n', 'sa', '<Cmd>Args<CR>')
		end,
	},
	{ 'capture.nvim' },
	{
		'colors.nvim',
		opts = {},
		after = function()
			pcall(require('colors').load_library)
		end,
	},
	{
		'commenter.nvim',
		after = function()
			nxo_map('gc', '<Plug>(commenter)')
			map('n', 'gcc', '<Plug>(commenter-current-line)')
		end,
	},
	{
		'context.nvim',
		after = function()
			map('n', '<C-w>x', '<Plug>(context-toggle)')
		end,
	},
	{
		'cword.nvim',
		after = function()
			map('n', 'sc', '<Plug>(cword-toggle)')
		end,
	},
	{ 'editorconfig.lua' },
	{ 'explorer.nvim' },
	{
		'fuzzy.nvim',
		after = function()
			map('n', '!', '<Cmd>FuzzyBuffers<CR>')
			map('n', 'g/', '<Cmd>FuzzyFiles<CR>')
			map('n', 'g]', '<Cmd>FuzzyTags<CR>')
		end,
	},
	{
		'git.nvim',
		after = function()
			map('n', 'sd', ':Gdiff<CR>')
			map('n', 'sgb', ':Gblame<CR>')
			map('x', 'sgl', ':Glog<CR>')
			map('n', 'gf', '<Plug>(git-goto-file)')
		end,
	},
	{
		'jumpmotion.nvim',
		after = function()
			nxo_map('<space>', '<Plug>(jumpmotion)')
		end,
	},
	{ 'man.lua' },
	{
		'multisearch.nvim',
		opts = {
			search_n = 5,
			very_magic = true,
		},
		after = function()
			map('n', 'sm', '<Cmd>MultiSearch<CR>')
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
	{ 'qf.nvim' },
	{ 'register.nvim' },
	{
		'searchfold.nvim',
		after = function()
			fmap('n', 'sf', function()
				require('searchfold').fold({
					context = vim.v.count1,
				})
			end)
		end,
	},
	{ 'star.nvim' },
	{
		'surround.nvim',
		after = function()
			map('n', 'ds', '<Plug>(surround-delete)')
			map('x', 's', '<Plug>(surround)')
		end,
	},
	{ 'textobjects.nvim' },
	{ 'tmux.nvim' },
	{ 'undowizard.nvim' },
	{
		'varign.nvim',
		opts = {},
	},
	{ 'vim-bufgrep' },
	{ 'vim-pastereindent' },
	{ 'vim-pets' },
	{ 'vim-tilde' },
	{ 'vimdent.nvim' },
	{
		'vnicode.nvim',
		opts = {},
		after = function()
			nxo_map('ga', '<Plug>(vnicode-inspect)')
		end,
	},
	{ 'wtf.nvim' },
})

require('init.statusline')
