local left = require('string.buffer').new()
local middle = require('string.buffer').new()
local right = require('string.buffer').new()
local output = require('string.buffer').new()

local function render_tabpage(s, tabpage, current)
	local win = vim.api.nvim_tabpage_get_win(tabpage)

	local buf = vim.api.nvim_win_get_buf(win)

	local path = vim.api.nvim_buf_get_name(buf)
	local name = string.match(path, '[^/]+$') or path
	if name == '' then
		name = '[No Name]'
	end
	local nr = vim.api.nvim_tabpage_get_number(tabpage)

	local flags = ''
	if vim.bo[buf].modified then
		flags = ' [+]'
	else
		local wins = vim.api.nvim_tabpage_list_wins(tabpage)
		for _, win in ipairs(wins) do
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.bo[buf].modified then
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

	local current_tabpage = vim.api.nvim_get_current_tabpage()

	local s = left
	for i, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
		if tabpage == current_tabpage then
			s = right
			render_tabpage(middle, tabpage, true)
		else
			render_tabpage(s, tabpage, false)
		end
	end

	right:put('%T%#TabLineFill#%<')

	local term_width = vim.o.columns
	local left_width = vim.api.nvim_eval_statusline(left:tostring(), {}).width
	local middle_width = vim.api.nvim_eval_statusline(middle:tostring(), {}).width
	local right_width = vim.api.nvim_eval_statusline(right:tostring(), {}).width

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
