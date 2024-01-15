local api = vim.api
local fn = vim.fn
local cmd = vim.cmd

local M = {}

local ns = api.nvim_create_namespace('surround')

local function keep_visual(win, callback)
	local buf = api.nvim_win_get_buf(win)
	local start_row, start_col = unpack(api.nvim_win_get_cursor(win))
	cmd.normal({ bang = true, args = { 'o' } })
	local end_row, end_col = unpack(api.nvim_win_get_cursor(win))

	local end_mark = '.'
	if
		not (start_row < end_row or (start_row == end_row and start_col <= end_col))
	then
		end_mark = 'v'
		start_row, start_col, end_row, end_col =
			end_row, end_col, start_row, start_col
	end

	end_col = fn.virtcol2col(win, end_row, fn.virtcol(end_mark))

	local id = api.nvim_buf_set_extmark(buf, ns, start_row - 1, start_col, {
		end_row = end_row - 1,
		end_col = end_col,
		right_gravity = false,
		end_right_gravity = true,
	})

	callback(buf, start_row, start_col, end_row, end_col)

	local start_row, start_col, details =
		unpack(api.nvim_buf_get_extmark_by_id(buf, ns, id, {
			details = true,
		}))
	local end_row, end_col = details.end_row, details.end_col

	api.nvim_win_set_cursor(win, { start_row + 1, start_col })
	cmd.normal({ bang = true, args = { 'o' } })
	api.nvim_win_set_cursor(win, { end_row + 1, math.max(end_col - 1, 0) })

	api.nvim_buf_del_extmark(buf, ns, id)
end

function M.is_visual_line()
	return vim.api.nvim_get_mode().mode == 'V'
end

function M.surround_visual_linewise(before, after)
	keep_visual(0, function(buf, start_row, start_col, end_row, end_col)
		api.nvim_buf_set_lines(buf, end_row, end_row, true, after)
		api.nvim_buf_set_lines(buf, start_row - 1, start_row - 1, true, before)
	end)
end

function M.surround_visual_charwise(before, after)
	keep_visual(0, function(buf, start_row, start_col, end_row, end_col)
		api.nvim_buf_set_text(
			buf,
			end_row - 1,
			end_col,
			end_row - 1,
			end_col,
			after
		)
		api.nvim_buf_set_text(
			buf,
			start_row - 1,
			start_col,
			start_row - 1,
			start_col,
			before
		)
	end)
end

local function leave_visual()
	vim.cmd.normal({
		bang = true,
		args = { vim.api.nvim_replace_termcodes('<Esc>', true, false, true) },
	})
end

local function split_lines(s)
	return vim.split(s, '\n')
end

function M.surround_visual(before, after, line_before, line_after)
	if M.is_visual_line() then
		M.surround_visual_linewise(
			split_lines(line_before or before),
			split_lines(line_after or after)
		)
	else
		M.surround_visual_charwise(split_lines(before), split_lines(after))
	end
	leave_visual()
end

return M
