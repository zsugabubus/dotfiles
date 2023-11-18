local api = vim.api

local left = require('string.buffer').new()
local middle = require('string.buffer').new()
local right = require('string.buffer').new()
local output = require('string.buffer').new()

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
	if api.nvim_buf_get_option(buf, 'modified') then
		flags = ' [+]'
	else
		for _, win in ipairs(api.nvim_tabpage_list_wins(tabpage)) do
			local buf = api.nvim_win_get_buf(win)
			if api.nvim_buf_get_option(buf, 'modified') then
				flags = ' +'
				break
			end
		end
	end

	s:put('%', nr, 'T')
	if current then
		s:put('%#TabLineSel#')
	else
		s:put('%#TabLine#')
	end
	s:put(' ', nr, ':', name, flags, ' ')
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
	local left_width = api.nvim_eval_statusline(left:tostring(), {}).width
	local middle_width = api.nvim_eval_statusline(middle:tostring(), {}).width
	local right_width = api.nvim_eval_statusline(right:tostring(), {}).width

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
	output:put('%', trim_width, '.', trim_width, '(', left, '%)')
	output:put(middle)
	output:put(right)
	return output:tostring()
end
