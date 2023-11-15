local group = vim.api.nvim_create_augroup('init/statusline', {})

vim.g.lnum_status = ''
local prev_lnum = 0

vim.api.nvim_create_autocmd('CursorMoved', {
	group = group,
	callback = function()
		local lnum = vim.api.nvim_win_get_cursor(0)[1]
		if lnum ~= prev_lnum then
			vim.g.lnum_status = string.format('%+d', lnum - prev_lnum)
			prev_lnum = lnum
		end
	end,
})

vim.api.nvim_create_autocmd({ 'WinLeave', 'FocusLost' }, {
	group = group,
	callback = function()
		vim.wo.statusline = table.concat({
			'%#StatusLineNC#%n:%f%( %m%)',
			'%=',
			' %l/%L,%-3v',
		})
	end,
})

vim.api.nvim_create_autocmd(
	{ 'VimEnter', 'WinEnter', 'BufWinEnter', 'FocusGained' },
	{
		group = group,
		callback = function()
			vim.wo.statusline = table.concat({
				"%(%#StatusLineModeTerm#%{'t'==mode()?'  T ':''}%#StatusLineModeTermEnd#%{'t'==mode()?' ':''}%#StatusLine#%)",
				"%(%( %{!&diff&&argc()>#1?(argidx()+1).' of '.argc():''} %)%(  %{v:lua.git_status()} %) %)",
				'%n:%f%( %h%w%r%)%( %m%)',
				'%9*%#StatusLine#',
				'%= ',
				'%1*%2*',
				"%(  %{&spell?&spelllang:''} %)",
				"%(  %{substitute(&binary?'bin':(!empty(&fenc)?&fenc:&enc).(&bomb?',bom':'').','.&fileformat,'^utf-8,unix$','','')} %)",
				"%( %{!&binary&&!empty(&ft)?&ft:''} %)",
				'%3* %l(%{lnum_status})/%L,%-3v',
			})
		end,
	}
)
