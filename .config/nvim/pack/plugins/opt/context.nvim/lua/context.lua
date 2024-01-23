local api = vim.api
local fn = vim.fn

local M = {}

local enabled = false
local context = {}
local prev_win
local prev_buf
local prev_tick
local prev_width
local search_cache = {}

local function clear()
	for _, x in ipairs(context) do
		pcall(api.nvim_win_close, x.win, true)
	end
	context = {}
end

local function update()
	local curr_win = api.nvim_get_current_win()
	local curr_buf = api.nvim_get_current_buf()
	local curr_tick = api.nvim_buf_get_var(curr_buf, 'changedtick')
	local curr_width = api.nvim_win_get_width(curr_win)
	local curr_line = api.nvim_win_get_cursor(curr_win)[1]

	local lines = {}

	if curr_buf ~= prev_buf or curr_tick ~= prev_tick then
		search_cache = {}
	end

	do
		local line = fn.prevnonblank(curr_line)
		local view

		while true do
			if search_cache[line] then
				line = search_cache[line]
			else
				local from_line = line
				local indent = fn.indent(line)
				if indent == 0 then
					line = 0
				else
					if not view then
						view = fn.winsaveview()
					end
					local pattern =
						string.format([=[\v\C^[ \t]*[("]*[a-zA-Z]%%<%dv]=], indent + 1)
					line = fn.search(pattern, 'cbW', 0, 200)
				end
				search_cache[from_line] = line
			end
			if line == 0 then
				break
			end
			table.insert(lines, 1, line)
		end

		if view then
			fn.winrestview(view)
		end
	end

	do
		local top_line = fn.line('w0')

		while #lines > 0 do
			-- Remove on-screen context lines.
			if lines[#lines] >= top_line + #lines - 1 then
				table.remove(lines, #lines)
			-- Disallow covering cursor by context lines. Remove least significant
			-- items to shorten it.
			elseif curr_line < #lines + top_line then
				table.remove(lines, 1 + math.floor(#lines / 2))
			else
				break
			end
		end
	end

	if curr_win ~= prev_win then
		clear()
	end

	for i = 1, #lines do
		local line = lines[i]
		local is_last = i == #lines
		local item = context[i]

		if item then
			if curr_buf ~= prev_buf then
				api.nvim_win_set_buf(item.win, curr_buf)
			end

			if curr_width ~= prev_width then
				api.nvim_win_set_width(item.win, curr_width)
			end
		else
			local win = api.nvim_open_win(curr_buf, false, {
				relative = 'win',
				win = curr_win,
				focusable = false,
				noautocmd = true,
				height = 1,
				width = curr_width,
				col = 0,
				row = i - 1,
			})
			local wo = vim.wo[win]
			wo.foldenable = false
			if wo.number or wo.relativenumber then
				wo.number = true
				wo.relativenumber = false
			end
			item = { win = win, line = nil, is_last = nil }
			table.insert(context, item)
		end

		if item.line ~= line then
			item.line = line
			api.nvim_win_set_cursor(item.win, { line, 0 })
		end

		if item.is_last ~= is_last then
			api.nvim_win_set_option(
				item.win,
				'winhighlight',
				string.format(
					'NormalFloat:%s,CursorLineNr:LineNr',
					is_last and 'NormalUnderline' or 'Normal'
				)
			)
		end
	end

	for _ = #lines + 1, #context do
		local win = table.remove(context).win
		api.nvim_win_close(win, true)
	end

	prev_win = curr_win
	prev_buf = curr_buf
	prev_tick = curr_tick
	prev_width = curr_width
end

local function check()
	for _, x in ipairs(context) do
		if not api.nvim_win_is_valid(x.win) then
			clear()
			update()
			return
		end
	end
end

local function update_highlights()
	api.nvim_set_hl(0, 'NormalUnderline', {
		default = true,
		underline = true,
	})
end

local timer = vim.loop.new_timer()
local should_update
local function timer_callback()
	if should_update then
		should_update = false
		vim.schedule(update)
	else
		timer:stop()
	end
end

function M.toggle(b)
	if b == nil then
		b = not enabled
	end
	enabled = b

	local group = api.nvim_create_augroup('context', {})
	timer:stop()
	clear()

	if not enabled then
		return
	end

	api.nvim_create_autocmd('ColorScheme', {
		group = group,
		callback = update_highlights,
	})

	api.nvim_create_autocmd(
		{ 'BufEnter', 'CursorMoved', 'WinEnter', 'WinScrolled' },
		{
			group = group,
			callback = function()
				if fn.reg_executing() ~= '' then
					return
				end

				should_update = true
				if not timer:is_active() then
					timer:start(10, 125, timer_callback)
				end
			end,
		}
	)

	api.nvim_create_autocmd('WinClosed', {
		group = group,
		callback = function()
			vim.schedule(check)
		end,
	})

	update_highlights()
	update()
end

return M
