local api = vim.api
local fn = vim.fn

local alphabet = 'abcdefghijklmnopqrstuvwxyz'

local unused_ns = {}
local win_ns = {}

local function get_win_ns(win)
	local ns = win_ns[win]
	if not ns then
		ns = table.remove(unused_ns) or api.nvim_create_namespace('')
		win_ns[win] = ns
		api.nvim__win_add_ns(win, ns)
	end
	return ns
end

local function reset_win_ns()
	for win, ns in pairs(win_ns) do
		if api.nvim_win_is_valid(win) then
			api.nvim__win_del_ns(win, ns)
		end
		table.insert(unused_ns, ns)
	end
	win_ns = {}
end

local function echo(text, hl_group)
	api.nvim_echo({ { text, hl_group } }, false, {})
end

local function find_targets(pattern, all_bufs)
	local targets = {}
	local current_win = api.nvim_get_current_win()
	local current_buf = api.nvim_get_current_buf()
	local current_row, current_col = unpack(api.nvim_win_get_cursor(current_win))

	local function add_win_targets()
		local win_targets = {}

		local win = api.nvim_get_current_win()
		local buf = api.nvim_win_get_buf(win)

		local view = fn.winsaveview()
		local top_row = view.topline
		local bot_row = fn.line('w$')
		local left_col = view.leftcol
		local right_col = left_col + api.nvim_win_get_width(0)

		local wrap = vim.o.wrap

		local flags = 'cWz'
		api.nvim_win_set_cursor(0, { top_row, 0 })

		while true do
			local row, col = unpack(fn.searchpos(pattern, flags, bot_row, 100))
			if row == 0 then
				break
			end
			col = col - 1
			flags = 'Wz'

			local fold_end = fn.foldclosedend(row)
			if fold_end >= 0 then
				if fold_end >= bot_row then
					break
				end
				api.nvim_win_set_cursor(0, { fold_end + 1, 0 })
				flags = 'cWz'
				goto skip
			end

			if not wrap then
				local virt_col = fn.virtcol('.')

				if virt_col < left_col then
					local new_col = fn.virtcol2col(0, row, left_col)
					if col + 1 < new_col then
						api.nvim_win_set_cursor(0, { row, new_col })
						flags = 'cWz'
						goto skip
					else
						-- Short line.
						virt_col = math.huge
					end
				end

				if right_col < virt_col then
					if row == bot_row then
						break
					end
					api.nvim_win_set_cursor(
						0,
						{ row + 1, math.max(0, fn.virtcol2col(0, row + 1, left_col) - 1) }
					)
					flags = 'cWz'
					goto skip
				end
			end

			if buf == current_buf and row == current_row and col == current_col then
				goto skip
			end

			table.insert(win_targets, { row, col })

			::skip::
		end

		fn.winrestview(view)

		for _, target in ipairs(win_targets) do
			local row, col = unpack(target)
			local visible = fn.screenpos(0, row, col + 1).row ~= 0
			if visible then
				table.insert(targets, {
					win = win,
					buf = buf,
					row = row,
					col = col,
				})
			end
		end
	end

	-- Current window first.
	add_win_targets()

	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		if
			win ~= current_win
			and api.nvim_win_get_config(win).focusable
			and (all_bufs or api.nvim_win_get_buf(win) == current_buf)
		then
			api.nvim_win_call(win, add_win_targets)
		end
	end

	return targets
end

local function make_word(n)
	local word = ''
	local k, i = n

	while k > 0 do
		k = k - 1
		k, i = math.floor(k / #alphabet), k % #alphabet + 1
		word = string.sub(alphabet, i, i) .. word
	end

	return word
end

local function assign_keys(targets)
	local target_by_key = {}
	local n = 1

	for _, target in ipairs(targets) do
		while true do
			local key = make_word(n)
			n = n + 1

			local conflict = target_by_key[string.sub(key, 1, -2)]
			if conflict then
				target_by_key[conflict.key] = nil
				conflict.key = key
				target_by_key[conflict.key] = conflict
			else
				target.key = key
				target_by_key[key] = target
				break
			end
		end
	end
end

local function set_default_highlights()
	api.nvim_set_hl(0, 'JumpMotionHead', {
		default = true,
		bold = true,
		ctermfg = 196,
		ctermbg = 226,
		fg = '#ff0000',
		bg = '#ffff00',
	})

	api.nvim_set_hl(0, 'JumpMotionTail', {
		default = true,
		link = 'JumpMotionHead',
	})
end

local function map_target(target)
	target.extmark_id = api.nvim_buf_set_extmark(
		target.buf,
		get_win_ns(target.win),
		target.row - 1,
		target.col,
		{
			id = target.extmark_id,
			virt_text = {
				{ string.sub(target.key, 1, 1), 'JumpMotionHead' },
				{ string.sub(target.key, 2), 'JumpMotionTail' },
			},
			virt_text_pos = 'overlay',
			priority = 1000,
			scoped = true,
		}
	)
end

local function unmap_target(target)
	if not target.extmark_id then
		return
	end
	api.nvim_buf_del_extmark(
		target.buf,
		get_win_ns(target.win),
		target.extmark_id
	)
end

local function pick_target(targets)
	set_default_highlights()
	reset_win_ns()

	while #targets > 1 do
		for _, target in ipairs(targets) do
			map_target(target)
		end

		echo('jumpmotion: ', 'Question')
		vim.cmd.redraw()
		local ok, c = pcall(fn.getcharstr)
		echo('', 'Normal')

		if not ok then
			for _, target in ipairs(targets) do
				unmap_target(target)
			end
			return
		end

		local new_targets = {}

		for _, target in ipairs(targets) do
			if string.sub(target.key, 1, #c) == c then
				target.key = string.sub(target.key, #c + 1)
				table.insert(new_targets, target)
			else
				unmap_target(target)
			end
		end

		targets = new_targets
	end

	local target = targets[1]

	if not target then
		echo('jumpmotion: No matches', 'ErrorMsg')
		return
	end

	unmap_target(target)

	return target
end

local function jump(pattern)
	local mode = api.nvim_get_mode().mode

	local targets = find_targets(pattern, mode == 'n')
	assign_keys(targets)

	local target = pick_target(targets)

	if not target then
		return false
	end

	-- Push current location to jumplist.
	api.nvim_command("normal! m'")

	api.nvim_set_current_win(target.win)
	api.nvim_win_set_cursor(target.win, { target.row, target.col })

	if mode == 'v' or mode == 'V' then
		api.nvim_command('normal! m>gv')
	end

	return true
end

return {
	jump = jump,
}
