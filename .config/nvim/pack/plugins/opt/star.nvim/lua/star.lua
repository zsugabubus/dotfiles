local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local go = vim.go

local M = {}

local function is_normal_mode()
	return string.sub(api.nvim_get_mode().mode, 1, 1) == 'n'
end

local function get_keyword(buf, row, col)
	local re = vim.regex(
		string.format(
			[=[\v\k*%%%dc\k+|%%%dc[^[:keyword:]]*\zs\k+]=],
			col + 1,
			col + 1
		)
	)
	local start_col, end_col = re:match_line(buf, row - 1, 0)

	if start_col then
		local text =
			api.nvim_buf_get_text(buf, row - 1, start_col, row - 1, end_col, {})[1]
		return text, start_col, end_col
	end
end

local function get_visual_text()
	local value = fn.getreg('', 1, true)
	local mode = fn.getregtype('')

	cmd.normal({ bang = true, args = { 'y' } })
	local text = fn.getreg('')

	fn.setreg('', value, mode)

	return text
end

local function set_search(pattern, offset)
	local view = fn.winsaveview()

	local wrapscan = go.wrapscan
	local shortmess = go.shortmess

	go.wrapscan = false -- Avoid "search hit TOP/BOTTOM without match" error.
	go.shortmess = 'sS' -- Avoid "search hit TOP/BOTTOM" warning.

	pcall(cmd.normal, {
		bang = true,
		args = {
			string.format(
				'/%s/%s\n',
				string.gsub(string.gsub(pattern, '/', '\\/'), '\n', '\\n'),
				offset
			),
		},
	})

	go.wrapscan = wrapscan
	go.shortmess = shortmess

	fn.winrestview(view)
end

function M.search(flags)
	local word = string.find(flags, 'w')
	local forward = not string.find(flags, 'b')

	local text
	local offset

	if is_normal_mode() then
		local row, col = unpack(api.nvim_win_get_cursor(0))
		local word, start_col, end_col = get_keyword(0, row, col)

		if not word then
			api.nvim_echo({
				{ 'E348: No string under cursor', 'ErrorMsg' },
			}, false, {})
			return
		end

		text = word
		if col + 1 == end_col then
			offset = 'e'
		else
			offset = string.format('s+%d', math.max(0, col - start_col))
		end
	else
		text = get_visual_text()
		offset = ''
	end

	local pattern = string.format(
		'\\V%s%s%s',
		word and '\\<' or '',
		string.gsub(text, '\\', '\\\\'),
		word and '\\>' or ''
	)
	set_search(pattern, offset)

	api.nvim_feedkeys(forward and 'n' or 'N', 'xtin', false)
end

return M
