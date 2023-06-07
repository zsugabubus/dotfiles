local M = setmetatable({}, {
	__index = function(_, key)
		M = require('colorcolors')
		return M[key]
	end,
})
local group = vim.api.nvim_create_augroup('ColorColors', {})

vim.api.nvim_create_autocmd('BufWinEnter', {
	group = group,
	callback = function()
		M.toggle_buffer(nil, true)
	end,
})

vim.api.nvim_create_autocmd('VimEnter', {
	group = group,
	callback = function()
		vim.api.nvim_create_autocmd('ColorScheme', {
			group = group,
			callback = function()
				M._reset_hls()
			end,
		})
	end,
	once = true,
})

vim.api.nvim_create_user_command('ColorColorsAttachToBuffer', function()
	M.toggle_buffer(nil, true)
end, {})

vim.api.nvim_create_user_command('ColorColorsDetachFromBuffer', function()
	M.toggle_buffer(nil, false)
end, {})

vim.api.nvim_create_user_command('ColorColorsToggleBuffer', function()
	M.toggle_buffer()
end, {})
