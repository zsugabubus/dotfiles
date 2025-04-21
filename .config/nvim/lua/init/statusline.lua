local group = vim.api.nvim_create_augroup('init/statusline', {})

local inactive = table.concat({
	'%#StatusLineNC#',
	'%n:%f%( %m%)',
	'%#VertSplit#  %=  %#StatusLineNC#',
	' %l/%L,%-3v',
})

local active = table.concat({
	'%#StatusLine#',
	"%(%#StatusLineBold# %{%'t'==mode()?' Terminal':''%} %#StatusLine# %)",
	"%( (%{argc()>1&&!&diff?(argidx()+1).' of '.argc():''}) %)",
	'%(  %{v:lua.git_status()}  %)',
	'%#StatusLineBold#%n:%f%( %h%w%r%)%( %m%)%#StatusLine#',
	'%#VertSplit#  %=  %#StatusLine#',
	"%( %{&spell?&spelllang:''}  %)",
	"%( %{substitute((empty(&fileencoding)?'utf-8':&fileencoding).(&bomb?',bom':'').','.&fileformat,'^utf-8,unix$','','')}  %)",
	'%( %{&filetype}  %)',
	'%#StatusLineBold#%l%#StatusLine#/%L,%#StatusLineBold#%-3v%#StatusLine#',
})

vim.api.nvim_create_autocmd('WinLeave', {
	group = group,
	callback = function()
		vim.wo.statusline = inactive
	end,
})

vim.api.nvim_create_autocmd({ 'VimEnter', 'WinEnter', 'BufWinEnter' }, {
	group = group,
	callback = function()
		vim.wo.statusline = active
	end,
})
