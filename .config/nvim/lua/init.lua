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
local g = vim.g
local o = vim.o
local wo = vim.wo

local autocmd = api.nvim_create_autocmd
local buf_keymap = api.nvim_buf_set_keymap
local keymap = api.nvim_set_keymap
local del_keymap = api.nvim_del_keymap
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('init', {})

local MAP_OPTS = { noremap = true }
local function map(mode, lhs, rhs)
	return keymap(mode, lhs, rhs, MAP_OPTS)
end

local function unmap(mode, lhs)
	return del_keymap(mode, lhs)
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
local function bsmap(mode, lhs, rhs)
	return buf_keymap(0, mode, lhs, rhs, SMAP_OPTS)
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
		("getcmdtype() ==# ':' && getcmdpos() ==# %d ? %s : %s"):format(
			#lhs + 1,
			fn.string(rhs),
			fn.string(lhs)
		)
	)
end

function _G.tabline()
	return require('init.tabline')()
end

local linux = vim.env.TERM == 'linux'

o.autoindent = true
o.cinoptions = 't0,:0,l1'
o.completeopt = 'menu,longest,noselect,preview'
o.copyindent = true
o.cursorline = true
o.cursorlineopt = 'number'
o.diffopt = 'closeoff,filler,vertical,algorithm:patience'
o.expandtab = false
o.fileignorecase = true
o.fillchars = linux and 'stlnc:─' or ''
o.foldopen = ''
o.grepformat = '%f:%l:%c:%m'
o.grepprg = 'noglob rg --vimgrep --smart-case'
o.hidden = true
o.ignorecase = true
o.joinspaces = false -- No double space.
o.laststatus = 2
o.lazyredraw = true
o.list = true
o.listchars = linux
		and 'eol:$,tab:> ,trail:+,extends::,precedes::,nbsp:_,space:·'
	or 'eol:$,tab:› ,trail:•,extends:⟩,precedes:⟨,nbsp:␣,space:·'
o.modelines = 1
o.more = false
o.mouse = ''
o.number = true
o.relativenumber = true
o.scrolloff = 5
o.shiftwidth = 0
o.shortmess = o.shortmess .. 'mrFI'
o.showbreak = '\\'
o.sidescrolloff = 23
o.smartcase = true
o.splitright = true
o.swapfile = false
o.switchbuf = ''
o.tabline = '%!v:lua.tabline()'
o.termguicolors = not linux
o.timeoutlen = 600
o.title = not linux
o.undodir = fn.stdpath('cache') .. '/undo'
o.undofile = true
o.wildignore = '.git,*.lock,*~,node_modules'
o.wildignorecase = true
o.wildmenu = true
o.wildmode = 'longest:full,full'
o.wrap = false

do
	local theme_file = fn.stdpath('config') .. '/theme.vim'

	local function update_theme()
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
			update_theme()
			cmd.redraw({ bang = true })
		end,
	})

	update_theme()
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

	local function update_terminal_palette()
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
			update_terminal_palette()
		end,
	})

	update_terminal_palette()
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

fmap('i', '<C-f>', function()
	local s = fn.expand('%:t:r')
	if s == 'init' or s == 'index' or s == 'main' then
		s = fn.expand('%:p:h:t')
	end
	api.nvim_paste(s, false, -1)
end)

map('i', '<C-r>', '<C-r><C-o>')

map('n', 'U', '')
map('n', 'gx', '')
map('x', 'gx', '')

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
	fn.setreg('p', fn.expand('%'):match('^(.*/)[^/]') or './')
	return ':edit <C-R>p<C-Z>'
end)
smap('n', '<M-q>', ':quit<CR>')
smap('n', '<M-w>', ':silent! wa|silent! wa<CR>')

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
xmap('n', '<C-w>d', function()
	return wo.diff and ':diffoff!<CR>' or ':windo diffthis<CR>'
end)

xmap('n', 's;', function()
	return 'A' .. (o.filetype == 'python' and ':' or ';') .. '<Esc>'
end)
map('n', 's,', 'A,<Esc>')

fmap('n', 'sb', function()
	local x = not wo.scrollbind
	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		wo[win][0].scrollbind = x
	end
end)
function _G.sort()
	cmd([[:'[,']sort /\v^(#!)@!\A*\zs/]])
end
remap('x', 'gs', "<Esc>'<V'><Esc>gs'<V'>")
xmap('n', 'gs', function()
	o.operatorfunc = 'v:lua.sort'
	return 'g@'
end)
remap('n', 'sp', 'gsip')
smap('n', 'sq', ':Qf<CR>')
smap('n', 'sQ', ':tabnew|Qe<CR>')
smap('n', 'st', ':Tlast<CR>')
smap('n', 'sD', ':Dup<CR>')
map('n', 'ss', ':%s//g<Left><Left>')
remap('n', 's/', 'ss/')
map('x', 'ss', ':s//g<Left><Left>')
remap('x', 's/', 'ss/')
smap('n', 'sw', ':set wrap!<CR>')
smap('n', 'sh', ':nohlsearch<CR>')
smap('n', 'se', ':edit<CR>')
smap('n', 's<space>', ':nmap <lt>buffer> <lt>space> <lt>C-d><CR>')

local function half_map(lhs, reg)
	xmap('o', lhs, function()
		local pos = fn.getpos('.')
		local op = vim.v.operator
		local func = o.operatorfunc
		function _G.bracket(mode)
			local v = mode == 'line' and 'V' or 'v'
			o.operatorfunc = func
			fn.setpos(reg, pos)
			fn.feedkeys('`[' .. op .. v .. '`]', 'i')
		end
		o.operatorfunc = 'v:lua.bracket'
		return '<Esc>g@'
	end)
end

half_map(']', "'[")
half_map('[', "']")

map('n', 'Q', ':normal n.<CR>zz')

-- Repeat over visual block
map('x', '.', ':normal! .<CR>')

-- Execute macro over visual range
xmap('x', '@', function()
	return (':normal! @%s<CR>'):format(fn.getcharstr())
end)

-- Reindent inner % lines.
remap('n', '>i', '>%<<$%<<$%')
remap('n', '<i', '<%>>$%>>$%')

map('x', '>', '>gv')
map('x', '<', '<gv')

-- Linewise {, }.
map('o', '{', 'V{')
map('o', '}', 'V}')

unmap('n', 'gri')
unmap('n', 'grr')
unmap('n', 'gra')
unmap('n', 'grn')

map('n', 'gr', ':GREP ')
map('n', 'gw', ':GREP -swF <C-r>=shellescape(expand("<cword>"))<CR><CR>')
map('x', '//', 'y:GREP -F <C-r>=shellescape(@", 1)<CR><CR>')
remap('x', 'gr', '//')

map('t', '<C-v>', '<C-\\><C-n>')

fmap('n', 'cd', function()
	cmd.cd(fn.expand('%:p' .. (':h'):rep(vim.v.count1)))
end)

map('n', 'c-', ':cd -<CR>')

cabbr('ccd', 'cd %:p:h<C-Z>')
cabbr('lcd', 'lcd %:p:h<C-Z>')
cabbr('tcd', 'tcd %:p:h<C-Z>')

cabbr('bg', 'BufGrep')
cabbr('hg', 'helpgrep')
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
		cmd(('%s -g %s'):format(base, fn.shellescape(opts.args)))
	end
end, { nargs = '*' })

user_command(
	'Japan',
	[[keepjumps keeppatterns lockmarks silent %s/\m\s\+$//e]],
	{}
)

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

user_command('Dup', function()
	local path = fn.tempname()
	cmd.mksession(path)
	fn.system({ 'tmux', 'new-window', 'nvim', '-S', path })
end, {})

autocmd({ 'FocusGained', 'VimEnter' }, {
	group = group,
	callback = function()
		local group = api.nvim_create_augroup('init/clipboard', {})
		autocmd('TextYankPost', {
			group = group,
			once = true,
			callback = function()
				autocmd({ 'FocusLost', 'VimSuspend' }, {
					group = group,
					callback = function()
						fn.setreg('+', fn.getreg('@'))
					end,
				})
			end,
		})
	end,
})

autocmd({ 'BufEnter', 'FileType' }, {
	group = group,
	callback = function()
		autocmd('InsertEnter', {
			group = group,
			buffer = 0,
			once = true,
			callback = function()
				require('init.snippets')()
			end,
		})
	end,
})

autocmd('FocusGained', {
	group = group,
	nested = true,
	callback = function()
		for _, buf in ipairs(api.nvim_list_bufs()) do
			if fn.bufname(buf):find('^tmux://panes/') and not bo[buf].modified then
				api.nvim_buf_call(buf, cmd.edit)
			end
		end
	end,
})

autocmd('BufWritePost', {
	group = group,
	pattern = '*.lua',
	callback = function(opts)
		local dir = fn.fnamemodify(opts.file, ':p:h')
		local colors_dir = fn.stdpath('config') .. '/colors'
		if dir == colors_dir then
			fn.system({ 'pkill', '-x', 'nvim', '-USR1' })
		end
	end,
})

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
			if fn.getline(1):find('^#!') then
				local uv = vim.loop
				local bit = require('bit')
				local mode = uv.fs_stat(opts.file).mode
				local ugo_x = tonumber('111', 8)
				uv.fs_chmod(opts.file, bit.bor(mode, ugo_x))
			end
		end)
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

		-- After +AnsiEsc.
		vim.schedule(function()
			autocmd('TextChanged', {
				buffer = 0,
				once = true,
				callback = function()
					bo.buftype = ''
				end,
			})
		end)
	end,
})

autocmd('BufReadPost', {
	group = group,
	callback = function()
		autocmd('BufEnter', {
			group = group,
			buffer = 0,
			once = true,
			callback = function()
				local ft = bo.filetype
				if ft:find('^git') or ft == 'mail' then
					return
				end
				cmd('silent! normal! g`"zvzz')
			end,
		})
	end,
})

autocmd('TermClose', {
	group = group,
	callback = function()
		cmd.stopinsert()
	end,
})

autocmd('FocusLost', {
	group = group,
	callback = function()
		pcall(fn.writefile, { fn.expand('%:p') }, fn.stdpath('run') .. '/nvim_here')
	end,
})

vim.filetype.add({
	pattern = {
		['/tmp/fstab%.'] = 'fstab',
		['.*'] = {
			function(path, bufnr)
				local content = fn.getline(1)
				if content:find('^[* ]*%x%x%x%x%x%x') then
					return 'git'
				end
				if content:find('^%-+BEGIN.*PRIVATE KEY') then
					return 'privatekey',
						function()
							vim.schedule(function()
								cmd('set foldtext=-|silent keeppattern normal! zE2GV/^-/-1\rzf')
							end)
						end
				end
			end,
			{ priority = -math.huge },
		},
	},
})

-- vim.treesitter pulls in lot's of Lua code.
filetype('typescriptreact,typescript', function()
	vim.treesitter.language.register('tsx', 'typescriptreact')
	vim.treesitter.language.register('tsx', 'typescript')
	return true
end)

filetype('help', function()
	vim.treesitter.stop()
end)

filetype('lua,python,typescript,typescriptreact', function()
	vim.treesitter.start()
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
	wo[0][0]['spell'] = true
end)

filetype('json', function()
	bo.equalprg = 'jq'
end)

filetype('xml,html', function()
	bo.equalprg = 'xmllint --encode UTF-8 --html --nowrap --dropdtd --format -'
end)

filetype('directory', function()
	bsmap('n', 'gu', '<Plug>(explorer-goto-parent)')
	bsmap('n', 'g.', '<Plug>(explorer-cd)')
	bsmap('n', '<CR>', 'Vgf')
end)

filetype('cucumber', function()
	cmd.Varign()
end)

filetype('addresslist', function()
	bsmap('n', 'T', ':MailTo<CR>')
	bsmap('n', 'C', ':MailCc<CR>')
	bsmap('n', 'B', ':MailBcc<CR>')
end)

require('pack').add({
	{ 'addresslist.nvim' },
	{
		'align.nvim',
		before = function()
			nxo_map('gl', '<Plug>(align)')
			remap('n', 'gL', 'viigl|')
		end,
	},
	{ 'ansiesc.nvim' },
	{ 'archive.nvim' },
	{
		'arglist.nvim',
		before = function()
			map('n', 'sa', '<Cmd>Args<CR>')
		end,
	},
	{ 'capture.nvim' },
	{
		'cat.nvim',
		after = function()
			smap('x', 'sn', ':Narrow<CR>')
		end,
	},
	{
		'colors.nvim',
		after = function()
			pcall(require('colors').load_library)
		end,
	},
	{
		'commenter.nvim',
		before = function()
			nxo_map('gc', '<Plug>(commenter)')
			map('n', 'gcc', '<Plug>(commenter-current-line)')
			map('o', 'gc', '<Plug>(commenter)')
		end,
	},
	{
		'context.nvim',
		before = function()
			map('n', '<C-w>x', '<Cmd>ContextToggle<CR>')
		end,
	},
	{
		'cword.nvim',
		before = function()
			map('n', 'sc', '<Cmd>CwordToggle<CR>')
		end,
	},
	{ 'explorer.nvim' },
	{
		'fuzzy.nvim',
		before = function()
			map('n', '!', '<Cmd>FuzzyBuffers<CR>')
			map('n', 'g/', '<Cmd>FuzzyFiles<CR>')
			map('n', 'g]', '<Cmd>FuzzyTags<CR>')
		end,
	},
	{
		'git.nvim',
		before = function()
			map('n', 'sd', ':Gdiff<CR>')
			xmap('n', 's@', function()
				return '<Cmd>Gdiff @~' .. vim.v.count .. '<CR>'
			end)
			map('n', 'sgb', ':Gblame<CR>')
			map('x', 'sgl', ':Glog<CR>')
			map('n', 'gf', '<Plug>(git-goto-file)')
		end,
	},
	{
		'jumpmotion.nvim',
		before = function()
			nxo_map('<space>', '<Plug>(jumpmotion)')
		end,
	},
	{ 'man.lua' },
	{
		'markdown.nvim',
		before = function()
			autocmd('User', {
				group = group,
				pattern = 'MarkdownPreviewStart',
				callback = function(opts)
					fn.setreg('+', opts.data.browser_url)
				end,
			})

			autocmd('FileType', {
				group = group,
				pattern = 'markdown',
				callback = function()
					api.nvim_buf_create_user_command(0, 'Preview', function(opts)
						cmd.MarkdownPreviewStart(tostring(opts.count))
					end, { count = true })
				end,
			})

			autocmd('FileType', {
				group = group,
				pattern = 'markdown',
				once = true,
				callback = function(opts)
					if opts.buf == 1 then
						if not pcall(cmd.Preview, { count = 8080 }) then
							cmd.Preview()
						end
					end
				end,
			})
		end,
	},
	{
		'multisearch.nvim',
		before = function()
			g.multisearch = {
				highlights = { 'Search1', 'Search2', 'Search3', 'Search4', 'Search5' },
				very_magic = true,
			}
			map('n', 'sm', '<Cmd>MultiSearch<CR>')
		end,
	},
	{
		'nvim-treesitter',
		enabled = false,
		after = function()
			require('nvim-treesitter.configs').setup({
				indent = { enable = false },
				highlight = { enable = false },
				parser_install_dir = fn.stdpath('data') .. '/site',
			})
		end,
	},
	{ 'pets.nvim' },
	{ 'qf.nvim' },
	{ 'register.nvim' },
	{
		'searchfold.nvim',
		before = function()
			fmap('n', 'sf', function()
				require('searchfold').fold({
					context = vim.v.count1,
				})
			end)
		end,
	},
	{
		'snippets.nvim',
		before = function()
			local function keymap_is(...)
				keymap('i', ...)
				keymap('s', ...)
			end

			keymap_is('<Tab>', '', {
				expr = true,
				callback = function()
					return require('snippets').jump() or '\t'
				end,
			})
		end,
	},
	{ 'star.nvim' },
	{
		'surround.nvim',
		before = function()
			map('n', 'ds', '<Plug>(surround-delete)')
			map('x', 's', '<Plug>(surround)')
		end,
	},
	{ 'textobjects.nvim' },
	{ 'tilde.nvim' },
	{ 'tmux.nvim' },
	{
		'undowizard.nvim',
		before = function()
			map('n', 'su', ':Undotree<CR>:view<CR>')
			map('n', 'sU', ':<C-U>Undodiff <C-R>=v:count<CR><CR>')
		end,
	},
	{ 'varign.nvim' },
	{ 'vim-bufgrep' },
	{ 'vim-pastereindent' },
	{ 'vimdent.nvim' },
	{
		'vnicode.nvim',
		before = function()
			nxo_map('ga', '<Plug>(vnicode-inspect)')
		end,
	},
	{ 'wellness.nvim' },
	{ 'wtf.nvim' },
})

require('init.statusline')
