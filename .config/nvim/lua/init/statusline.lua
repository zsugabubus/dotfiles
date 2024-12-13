local group = vim.api.nvim_create_augroup('init/statusline', {})

vim.api.nvim_create_autocmd('WinLeave', {
	group = group,
	callback = function()
		vim.wo.statusline = table.concat({
			'%#StatusLineNC#%n:%f%( %m%)',
			'%=',
			' %l/%L,%-3v',
		})
	end,
})

vim.api.nvim_create_autocmd({ 'VimEnter', 'WinEnter', 'BufWinEnter' }, {
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
			"%(  %{substitute((empty(&fileencoding)?'utf-8':&fileencoding).(&bomb?',bom':'').','.&fileformat,'^utf-8,unix$','','')} %)",
			'%( %{&filetype} %)',
			'%3* %l/%L,%-3v',
		})
	end,
})
