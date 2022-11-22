local M = setmetatable({}, {
	__index = function(self, key)
		return require 'colorcolors'[key]
	end,
})
local api = vim.api
local group = api.nvim_create_augroup('ColorColors', {})

api.nvim_create_autocmd(
	{'BufWinEnter'},
	{
		group = group,
		buffer = buffer,
		callback = function()
			M.toggle_buffer(nil, true)
		end,
	}
)

api.nvim_create_autocmd(
	{'Colorscheme'},
	{
		group = group,
		callback = function()
			M._reset_hls()
		end
	}
)
