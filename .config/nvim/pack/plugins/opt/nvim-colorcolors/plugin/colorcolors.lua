local M = setmetatable({}, {
	__index = function(self, key)
		return require 'colorcolors'[key]
	end,
})
local group = vim.api.nvim_create_augroup('ColorColors', {})

vim.api.nvim_create_autocmd('BufWinEnter', {
	group = group,
	buffer = buffer,
	callback = function()
		M.toggle_buffer(nil, true)
	end,
})

vim.api.nvim_create_autocmd('Colorscheme', {
	group = group,
	callback = function()
		M._reset_hls()
	end,
})

vim.api.nvim_create_user_command(
	'ColorColorsAttachToBuffer',
	function()
		M.toggle_buffer(nil, true)
	end,
	{}
)

vim.api.nvim_create_user_command(
	'ColorColorsDetachFromBuffer',
	function()
		M.toggle_buffer(nil, false)
	end,
	{}
)

vim.api.nvim_create_user_command(
	'ColorColorsToggleBuffer',
	function()
		M.toggle_buffer()
	end,
	{}
)
