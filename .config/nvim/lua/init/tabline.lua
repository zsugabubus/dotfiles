local api = vim.api

local EVAL_TABLINE_WIDTH = { use_tabline = true }

local left = require('string.buffer').new()
local middle = require('string.buffer').new()
local right = require('string.buffer').new()
local output = require('string.buffer').new()

local function esc(s)
	return string.gsub(s, '%%', '%%%%')
end

local function render_tabpage(s, tabpage, current)
	local nr = api.nvim_tabpage_get_number(tabpage)
	local win = api.nvim_tabpage_get_win(tabpage)
	local buf = api.nvim_win_get_buf(win)

	local name = api.nvim_buf_get_name(buf)
	if name == '' then
		name = '[No Name]'
	else
		name = string.match(name, '[^/]+/[^/]+/?$') or name
	end

	local flags = ''
	if api.nvim_get_option_value('modified', { buf = buf }) then
		flags = ' [+]'
	end

	s:put('%', nr, 'T')
	s:put(current and '%#TabLineSel#' or '%#TabLine#')
	s:put(' ', nr, ':', esc(name), flags, ' ')
end

local function get_width(s)
	return api.nvim_eval_statusline(s:tostring(), EVAL_TABLINE_WIDTH).width
end

return function()
	left:reset()
	middle:reset()
	right:reset()

	local current_tabpage = api.nvim_get_current_tabpage()

	local s = left
	for i, tabpage in ipairs(api.nvim_list_tabpages()) do
		if tabpage == current_tabpage then
			s = right
			render_tabpage(middle, tabpage, true)
		else
			render_tabpage(s, tabpage, false)
		end
	end

	right:put('%T%#TabLineFill#%<')

	local term_width = vim.o.columns
	local left_width = get_width(left)
	local middle_width = get_width(middle)
	local right_width = get_width(right)

	if left_width + middle_width + right_width <= term_width then
		left:put(middle, right)
		return left:tostring()
	end

	local trim_width = math.min(
		left_width,
		math.max(
			0,
			math.floor((term_width - middle_width) / 2),
			term_width - middle_width - right_width
		)
	)

	output:reset()
	output:put('%', trim_width, '.', trim_width, '(', left, '%)', middle, right)
	return output:tostring()
end
