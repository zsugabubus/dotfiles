local M = {}
local api, fn = vim.api, vim.fn
local ns = api.nvim_create_namespace('jumpmotion')

local function update_highlights()
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
		ctermfg = 196,
		ctermbg = 226,
		fg = '#ff0000',
		bg = '#ffff00',
	})
end

local function update_extmarks(targets)
	for _, target in ipairs(targets) do
		target.extmark_id =
			api.nvim_buf_set_extmark(target.buf, ns, target.line - 1, target.col, {
				id = target.extmark_id,
				virt_text = {
					{ string.sub(target.key, 1, 1), 'JumpMotionHead' },
						-- Empty virtual text makes Nvim confused.
					#target.key > 1 and { string.sub(target.key, 2), 'JumpMotionTail' }
						or nil,
				},
				virt_text_pos = 'overlay',
				priority = 1000 + #targets,
			})
	end
end

local function generate_word(n)
	local word = ''
	local a, z = string.byte('a'), string.byte('z')
	local len = z - a + 1
	local k = n
	while k > 0 do
		k = k - 1
		word = string.char(a + k % len) .. word
		k = math.floor(k / len)
	end
	return word
end

local function generate_keys(targets)
	local target_by_key = {}

	local n = 1
	for _, target in ipairs(targets) do
		while true do
			local key = generate_word(n)
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

local function pick_target(targets)
	update_highlights()

	while #targets > 1 do
		update_extmarks(targets)

		api.nvim_echo({
			{
				string.format('jumpmotion (%d targets): ', #targets),
				'Question',
			},
		}, false, {})
		vim.cmd.redraw()

		local ok, c = pcall(fn.getcharstr)
		if not ok then
			c = ' '
		end

		api.nvim_echo({
			{ '', 'Normal' },
		}, false, {})

		local new_targets = {}
		for _, target in ipairs(targets) do
			if string.sub(target.key, 1, #c) == c then
				target.key = string.sub(target.key, #c + 1)
				table.insert(new_targets, target)
			else
				api.nvim_buf_del_extmark(target.buf, ns, target.extmark_id)
			end
		end
		targets = new_targets
	end

	local target = targets[1]
	if not target then
		api.nvim_echo({
			{ 'jumpmotion: No matches', 'ErrorMsg' },
		}, false, {})
		return
	end

	-- Single target will have no extmark set.
	if target.extmark_id ~= nil then
		api.nvim_buf_del_extmark(target.buf, ns, target.extmark_id)
	end

	return target
end

local function find_targets(pattern)
	local targets = {}
	local targets_set = {}
	local current_win = api.nvim_get_current_win()

	local saved_scrolloff = vim.o.scrolloff
	vim.o.scrolloff = 0

	local function add_win_targets()
		local win = api.nvim_get_current_win()
		local buf = api.nvim_win_get_buf(win)

		local view = fn.winsaveview()
		view.botline = fn.line('w$')
		view.rightcol = view.leftcol + api.nvim_win_get_width(0) - 1

		local opt_wrap = vim.o.wrap

		local flags = 'cWz'
		api.nvim_win_set_cursor(0, { view.topline, 0 })

		while true do
			local lnum, col = unpack(fn.searchpos(pattern, flags, view.botline, 100))
			if lnum == 0 then
				break
			end
			col = col - 1
			flags = 'Wz'

			local fold_end = fn.foldclosedend(lnum)
			if fold_end >= 0 then
				if fold_end >= view.botline then
					break
				end
				api.nvim_win_set_cursor(0, { fold_end + 1, 0 })
				flags = 'cWz'
				goto continue
			end

			-- Skip non-visible portion of a line.
			if not opt_wrap then
				local virt_col = fn.virtcol('.')

				if virt_col < view.leftcol then
					local new_col = fn.virtcol2col(0, lnum, view.leftcol)
					if col + 1 < new_col then
						api.nvim_win_set_cursor(0, { lnum, new_col })
						flags = 'cWz'
						goto continue
					else
						-- Short line.
						virt_col = math.huge
					end
				end

				if view.rightcol < virt_col then
					-- `lnum + 1` may be after last line so this check is required.
					if lnum == view.botline then
						break
					end
					api.nvim_win_set_cursor(
						0,
						{ lnum + 1, fn.virtcol2col(0, lnum + 1, view.leftcol) }
					)
					flags = 'cWz'
					goto continue
				end
			end

			local visible = fn.screenpos(0, lnum, col + 1).row ~= 0
			if not visible then
				goto continue
			end

			local target_id = string.format('%d:%d:%d', buf, lnum, col)
			if targets_set[target_id] then
				goto continue
			end
			targets_set[target_id] = true

			table.insert(targets, {
				win = win,
				buf = buf,
				line = lnum,
				col = col,
			})

			::continue::
		end

		fn.winrestview(view)
	end

	-- Current window first.
	add_win_targets()

	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		if win ~= current_win and api.nvim_win_get_config(win).focusable then
			api.nvim_win_call(win, add_win_targets)
		end
	end

	vim.o.scrolloff = saved_scrolloff

	return targets
end

local last_pattern
function M.jump(pattern)
	local mode = fn.mode()

	local targets = find_targets(pattern)
	generate_keys(targets)

	vim.o.opfunc = 'v:lua._jumpmotion_noop'
	api.nvim_command('silent! normal! g@:\n')
	vim.o.opfunc = 'v:lua._jumpmotion_repeat'
	last_pattern = pattern

	local target = pick_target(targets)
	if not target then
		return false
	end

	-- Push current location to jumplist.
	api.nvim_command("normal! m'")

	api.nvim_set_current_win(target.win)
	api.nvim_win_set_cursor(target.win, { target.line, target.col })

	if mode == 'v' or mode == 'V' then
		api.nvim_command('normal! m>gv')
	end

	return true
end

function _G._jumpmotion_noop()
	-- Do nothing. Really.
end

function _G._jumpmotion_repeat()
	return M.jump(last_pattern)
end

return M
