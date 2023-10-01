local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

local M = {}

function M.get_cursor_text()
	local row, col = unpack(api.nvim_win_get_cursor(0))
	local line = api.nvim_buf_get_text(0, row - 1, col, row - 1, -1, {})[1]
	return fn.matchstr(line, '.')
end

function M.get_visual_text()
	local value = fn.getreg('', 1, true)
	local mode = fn.getregtype('')

	cmd.normal({ bang = true, args = { 'y' } })
	local text = fn.getreg('')

	fn.setreg('', value, mode)

	return text
end

function M.get_current_text()
	if vim.api.nvim_get_mode().mode == 'n' then
		return M.get_cursor_text()
	else
		return M.get_visual_text()
	end
end

return M
