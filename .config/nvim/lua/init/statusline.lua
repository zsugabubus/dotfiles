local group = vim.api.nvim_create_augroup('init/statusline', {})

_G.statusline_lnum_diff = ''
local prev_lnum = 0

vim.api.nvim_create_autocmd('CursorMoved', {
	group = group,
	pattern = '*',
	callback = function()
		local lnum = vim.api.nvim_win_get_cursor(0)[1]
		if lnum ~= prev_lnum then
			_G.statusline_lnum_diff = string.format('%+d', lnum - prev_lnum)
			prev_lnum = lnum
		end
	end,
})

vim.api.nvim_create_autocmd({ 'WinLeave', 'FocusLost' }, {
	group = group,
	pattern = '*',
	callback = function()
		vim.wo.statusline = table.concat({
			'%#StatusLineNC#%n:%f%h%w%( %m%)',
			'%=',
			'%l/%L:%-3v',
		})
	end,
})

vim.api.nvim_create_autocmd(
	{ 'VimEnter', 'WinEnter', 'BufWinEnter', 'FocusGained' },
	{
		group = group,
		pattern = '*',
		callback = function()
			vim.wo.statusline = table.concat({
				"%(%#StatusLineModeTerm#%{'t'==mode()?'  T ':''}%#StatusLineModeTermEnd#%{'t'==mode()?' ':''}%#StatusLine#%)",
				"%(%( %{!&diff&&argc()>#1?(argidx()+1).' of '.argc():''} %)%(  %{GitBuffer().status} %) %)",
				"%n:%f%h%w%{exists('b:gzflag')?'[GZ]':''}%r%( %m%)%k",
				'%9*%<%#StatusLine#',
				'%<%=',
				'%1*%2*',
				"%( %{&paste?'ρ':''} %)",
				"%( %{&spell?&spelllang:''}  %)",
				"%( %{substitute(&binary?'bin':(!empty(&fenc)?&fenc:&enc).(&bomb?',bom':'').(&fileformat!=#'unix'?','.&fileformat:''),'^utf-8$','','')} %)",
				"%( %{!&binary&&!empty(&ft)?&ft:''} %)",
				"%3* %l(%{luaeval('statusline_lnum_diff')})/%L:%-3v",
			})
		end,
	}
)
