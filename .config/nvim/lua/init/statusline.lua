local group = vim.api.nvim_create_augroup('init/statusline', {})
local linux = vim.env.TERM == 'linux'

local inactive = table.concat({
	'%n:%f%( %m%)',
	' %= ',
	'%l/%L,%-3v',
})

local active = table.concat({
	'%(',
	linux and '(' or '  ',
	'%{v:lua.git_status()}',
	linux and ')' or ' ',
	' %)',
	'%#StatusLineBold#',
	'%n:%f%( %h%w%r%)%( %m%)',
	'%#StatusLine#',
	"%( (%{argc()>1?(argidx()+1).' of '.argc():''})%)",
	' %= ',
	'%#StatusLineBold#',
	'%l',
	'%#StatusLine#',
	'/%L,',
	'%#StatusLineBold#',
	'%-3v',
	'%#StatusLine#',
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
