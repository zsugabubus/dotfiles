local api = vim.api
local bo = vim.bo
local cmd = vim.cmd
local concat = table.concat
local find = string.find
local fn = vim.fn
local format = string.format
local gsub = string.gsub
local insert = table.insert
local match = string.match
local remove = table.remove
local rep = string.rep
local sort = table.sort
local sub = string.sub

local augroup = api.nvim_create_augroup
local autocmd = api.nvim_create_autocmd
local buf_get_text = api.nvim_buf_get_text
local buf_keymap = api.nvim_buf_set_keymap
local buf_set_text = api.nvim_buf_set_text
local get_current_buf = api.nvim_get_current_buf
local keymap = api.nvim_set_keymap
local termcodes = api.nvim_replace_termcodes
local win_get_cursor = api.nvim_win_get_cursor
local win_set_cursor = api.nvim_win_set_cursor

local config = vim.g.snippets or {}
local get_snippets = config.get_snippets or function() end

if type(get_snippets) == 'string' then
	local modname = get_snippets
	get_snippets = function(...)
		get_snippets = require('snippets.source').new(require(modname))
		return get_snippets(...)
	end
end

local plug_callback = '<Plug>(_snippets-callback)'
local plug_callback_ks = termcodes(plug_callback, true, false, true)
local esc_ks = termcodes('<Esc>', true, false, true)

local jump_chars =
	{ '=', "'", '"', '(', ')', '{', '}', '[', ']', ':', ';', ',', '`', '<', '>' }
local jump_pat = format('[%s]', gsub(concat(jump_chars), '[%%%]]', '%%%1'))

local ns = api.nvim_create_namespace('')
local group = augroup('snippets', {})

local buf_states = {}
local buf_snippets = {}
local next_snippet_id = 0

local snippet_callbacks_by_key = setmetatable({}, {
	__mode = 'k',
	__index = function(cache, snippets)
		local t = {}

		for _, snippet in ipairs(snippets) do
			local c = snippet.key
			t[c] = t[c] or {}
			insert(t[c], snippet.callback)
		end

		cache[snippets] = t
		return t
	end,
})

local function range_from_pos(start_pos, end_pos)
	return { start_pos[1], start_pos[2], end_pos[1], end_pos[2] }
end

local function is_range_empty(range)
	return range[3] < range[1] or (range[1] == range[3] and range[4] <= range[2])
end

local function is_range_contains(range, pos)
	local start_row, start_col, end_row, end_col = unpack(range)
	local row, col = unpack(pos)
	return (row > start_row or (row == start_row and col >= start_col))
		and (row < end_row or (row == end_row and col <= end_col))
end

local function mapcb(cb)
	_G._snippets_callback = cb
	return plug_callback_ks
end

local function split(s, sep)
	local t = {}
	local i = 1

	while true do
		local j = find(s, sep, i, true)

		if not j then
			insert(t, sub(s, i))
			break
		end

		insert(t, sub(s, i, j - 1))

		i = j + #sep
	end

	return t
end

local function freq(s, pat)
	local _, n = gsub(s, pat, '')
	return n
end

local function split_lines(s)
	return split(s, '\n')
end

local function join_lines(lines)
	return concat(lines, '\n')
end

local function set_extmark(buf, id, range, right_gravity, end_right_gravity)
	return api.nvim_buf_set_extmark(buf, ns, range[1], range[2], {
		id = id,
		end_row = range[3],
		end_col = range[4],
		right_gravity = right_gravity,
		end_right_gravity = end_right_gravity,
	})
end

local function del_extmark(buf, id)
	api.nvim_buf_del_extmark(buf, ns, id)
end

local function get_extmark_range(buf, id)
	local result = api.nvim_buf_get_extmark_by_id(buf, ns, id, { details = true })
	return { result[1], result[2], result[3].end_row, result[3].end_col }
end

local function set_extmark_gravity(buf, id, right_gravity, end_right_gravity)
	local range = get_extmark_range(buf, id)
	set_extmark(buf, id, range, right_gravity, end_right_gravity)
end

local function get_extmark_text(buf, id)
	local range = get_extmark_range(buf, id)
	local lines = buf_get_text(buf, range[1], range[2], range[3], range[4], {})
	return join_lines(lines)
end

local function set_extmark_text(buf, id, text)
	local range = get_extmark_range(buf, id)
	local lines = split_lines(text)
	buf_set_text(buf, range[1], range[2], range[3], range[4], lines)
end

local function stopselect()
	cmd.normal({ esc_ks, bang = true })
end

local function select_range(range)
	local mode = api.nvim_get_mode().mode

	if is_range_empty(range) then
		if mode == 's' then
			stopselect()
			cmd.startinsert()
		end
		win_set_cursor(0, { range[1] + 1, range[2] })
	elseif mode == 's' then
		stopselect()
		win_set_cursor(0, { range[1] + 1, range[2] })
		cmd.normal({ 'gh', bang = true })
		win_set_cursor(0, { range[3] + 1, range[4] - 1 })
	else
		cmd.stopinsert()
		win_set_cursor(0, { range[1] + 1, range[2] })
		cmd.normal({ 'gh', bang = true })
		win_set_cursor(0, { range[3] + 1, range[4] })
	end
end

local function update_text(buf, state)
	for _, x in ipairs(state.tabstops) do
		if x.get_text then
			set_extmark_text(buf, x.extmark_id, x.get_text())
		end
	end

	for _, x in ipairs(state.placeholders) do
		if x.get_text then
			set_extmark_text(buf, x.extmark_id, x.get_text())
		end
	end
end

local function stop_if(buf, state, pred)
	local function f(x)
		if pred(x) then
			del_extmark(buf, x.extmark_id)
			return false
		end
		return true
	end

	state.sentinels = vim.tbl_filter(f, state.sentinels)
	state.tabstops = vim.tbl_filter(f, state.tabstops)
	state.placeholders = vim.tbl_filter(f, state.placeholders)

	if #state.tabstops == 0 then
		assert(#state.sentinels == 0)
		assert(#state.placeholders == 0)
		buf_states[buf] = nil
	end
end

local function stop_all(buf, state)
	stop_if(buf, state, function()
		return true
	end)
end

local function stop(buf, state, snippet_id)
	stop_if(buf, state, function(item)
		return item.snippet_id == snippet_id
	end)
end

local function leave_tabstop(state)
	local tabstop = remove(state.tabstops, 1)
	tabstop.get_text = nil
	insert(state.placeholders, tabstop)
end

local function enter_tabstop()
	local buf = get_current_buf()
	local state = buf_states[buf]
	local tabstop = state.tabstops[1]

	if not tabstop then
		stop_all(buf, state)
		return
	end

	if tabstop.final then
		leave_tabstop(state)
	end

	update_text(buf, state)
	select_range(get_extmark_range(buf, tabstop.extmark_id))

	if tabstop.final then
		stop(buf, state, tabstop.snippet_id)
	end
end

local function resolve_variable(name)
	if name == 'TM_SELECTED_TEXT' then
		return fn.getreg()
	end
end

local function handle_text_changed(opts)
	local buf = opts.buf
	local state = buf_states[buf]

	if not state then
		return true
	end

	for _, x in ipairs(state.sentinels) do
		if is_range_empty(get_extmark_range(buf, x.extmark_id)) then
			stop(buf, state, x.snippet_id)
			return handle_text_changed(opts)
		end
	end

	local row, col = unpack(win_get_cursor(0))
	local pos = { row - 1, col }
	local inside = false

	for _, x in ipairs(state.placeholders) do
		if is_range_contains(get_extmark_range(buf, x.extmark_id), pos) then
			inside = true
			x.get_text = nil
		end
	end

	for _, x in ipairs(state.tabstops) do
		if is_range_contains(get_extmark_range(buf, x.extmark_id), pos) then
			inside = true
			x.get_text = nil
		end
	end

	if not inside then
		stop_all(buf, state)
		return true
	end

	update_text(buf, state)
end

local function is_balanced(s)
	return freq(s, '%(') == freq(s, '%)')
		and freq(s, '{') == freq(s, '}')
		and freq(s, '%[') == freq(s, ']')
end

local function is_current_tabstop_valid(buf, state)
	local row, col = unpack(win_get_cursor(0))
	local tabstop = state.tabstops[1]
	local range = get_extmark_range(buf, tabstop.extmark_id)
	return is_range_contains(range, { row - 1, col })
end

local function jump()
	local buf = get_current_buf()
	local state = buf_states[buf]

	if not state then
		return
	end

	if not is_current_tabstop_valid(buf, state) then
		return
	end

	leave_tabstop(state)

	return mapcb(function()
		enter_tabstop()
	end)
end

local function attach_to_buffer(buf)
	autocmd({ 'TextChanged', 'TextChangedI' }, {
		group = augroup('snippets/' .. buf, {}),
		buffer = buf,
		callback = handle_text_changed,
	})
end

local function left(lnum, indent)
	cmd(format('%d left %d', lnum, indent))
end

local function indentexpr(lnum)
	if bo.indentexpr ~= '' then
		vim.v.lnum = lnum
		vim.g._snippets_indent = nil
		api.nvim_exec2(
			'silent! sandbox let g:_snippets_indent = eval(&indentexpr)',
			{}
		)
		-- Keep current indent.
		if vim.g._snippets_indent == -1 then
			return
		end
		return vim.g._snippets_indent
	elseif bo.cindent then
		return fn.cindent(lnum)
	elseif bo.lisp then
		return fn.lispindent(lnum)
	end
end

local function expand(buf, row, col, body, env)
	local sentinel_ranges = {}
	local has_tabstop = {}
	local tabstop_data = {}
	local placeholder_data = {}
	local snippet_lines = { '' }
	local inputs

	local start_row = row
	local start_col = col

	local snippet_id = next_snippet_id
	next_snippet_id = next_snippet_id + 1

	local function pos()
		return { row, col }
	end

	local add_nodes

	local function add_text(body, toplevel)
		if body == '' then
			return
		end

		local start_pos = pos()

		local lines = split_lines(body)
		if #lines == 1 then
			col = col + #lines[1]
		else
			row = row + #lines - 1
			col = #lines[#lines]
		end

		snippet_lines[#snippet_lines] = snippet_lines[#snippet_lines] .. lines[1]
		for i = 2, #lines do
			insert(snippet_lines, lines[i])
		end

		local end_pos = pos()
		local range = range_from_pos(start_pos, end_pos)

		if toplevel then
			insert(sentinel_ranges, range)
		end
	end

	local function get_jumper(nodes, node_index)
		local node = nodes[node_index + 1]

		if not node then
			return
		end

		if node.type ~= 'text' then
			return
		end

		return match(node.body, jump_pat)
	end

	local function add_tabstop(number, default, jumper)
		local get_text = env and env[number]
		local start_pos = pos()

		if type(get_text) == 'string' then
			add_text(get_text, false)
		elseif default then
			add_nodes(default, false)
		end

		insert(tabstop_data, {
			range = range_from_pos(start_pos, pos()),
			number = number,
			jumper = jumper,
			get_text = type(get_text) == 'function' and function()
				return get_text(inputs)
			end or nil,
		})

		has_tabstop[number] = true
	end

	local function add_mirror(number)
		insert(placeholder_data, {
			range = range_from_pos(pos(), pos()),
			get_text = function()
				return inputs[number]
			end,
		})
	end

	local function add_variable(name, default, toplevel)
		local get_text = env[name]

		if not get_text then
			local value = resolve_variable(name)
			if value then
				add_text(value, toplevel)
			elseif default then
				add_nodes(default, toplevel)
			end
			return
		elseif type(get_text) == 'string' then
			add_text(get_text, toplevel)
			return
		end

		insert(placeholder_data, {
			range = range_from_pos(pos(), pos()),
			get_text = function()
				return get_text(inputs)
			end,
		})
	end

	add_nodes = function(nodes, toplevel)
		for node_index, node in ipairs(nodes) do
			if node.type == 'text' then
				add_text(node.body, toplevel)
			elseif node.type == 'tabstop' then
				if has_tabstop[node.number] then
					add_mirror(node.number)
				else
					add_tabstop(node.number, node.default, get_jumper(nodes, node_index))
				end
			elseif node.type == 'variable' then
				add_variable(node.name, node.default, toplevel)
			end
		end
	end

	add_nodes(body, true)

	if not has_tabstop[0] then
		add_tabstop(0)
	end

	sort(tabstop_data, function(a, b)
		return a.number ~= 0 and a.number < b.number
	end)

	local white = buf_get_text(buf, start_row, 0, start_row, start_col, {})[1]
	local reindent = not find(white, '%S')

	-- Make `indent` stop at `start_col`.
	buf_set_text(buf, start_row, start_col, start_row, start_col, { 'x' })
	local base_indent = fn.indent(start_row + 1)
	buf_set_text(
		buf,
		start_row,
		start_col,
		start_row,
		start_col + 1,
		snippet_lines
	)

	if reindent then
		base_indent = indentexpr(start_row + 1) or base_indent
	end

	local state = buf_states[buf]

	if not state then
		state = {
			sentinels = {},
			tabstops = {},
			placeholders = {},
		}
		buf_states[buf] = state
	end

	local tabstops_by_number = {}

	inputs = setmetatable({}, {
		__index = function(_, number)
			return get_extmark_text(buf, tabstops_by_number[number].extmark_id)
		end,
	})

	for _, range in ipairs(sentinel_ranges) do
		insert(state.sentinels, {
			snippet_id = snippet_id,
			extmark_id = set_extmark(buf, nil, range, true, false),
		})
	end

	for i, data in ipairs(tabstop_data) do
		local tabstop = {
			snippet_id = snippet_id,
			extmark_id = set_extmark(buf, nil, data.range, true, true),
			get_text = data.get_text,
			jumper = data.jumper,
			final = data.number == 0,
		}
		insert(state.tabstops, i, tabstop)
		tabstops_by_number[data.number] = tabstop
	end

	for _, data in ipairs(placeholder_data) do
		insert(state.placeholders, {
			snippet_id = snippet_id,
			extmark_id = set_extmark(buf, nil, data.range, true, true),
			get_text = data.get_text,
		})
	end

	local shift = rep(' ', fn.shiftwidth())
	local function shift_indent(s)
		return #gsub(match(s, '^[\t ]*'), '\t', shift)
	end

	for i, line in ipairs(snippet_lines) do
		if reindent or i > 1 then
			left(start_row + i, base_indent + shift_indent(line))
		end
	end

	for _, x in ipairs(state.tabstops) do
		set_extmark_gravity(buf, x.extmark_id, x.final, true)
	end

	for _, x in ipairs(state.placeholders) do
		set_extmark_gravity(buf, x.extmark_id, false, true)
	end

	attach_to_buffer(buf)
	update_text(buf, state)
	enter_tabstop()
end

local function jump_char(c)
	local buf = get_current_buf()
	local state = buf_states[buf]

	if not state then
		return
	end

	if not is_current_tabstop_valid(buf, state) then
		return
	end

	local tabstop = state.tabstops[1]

	if tabstop.jumper ~= c then
		return
	end

	local s = get_extmark_text(buf, tabstop.extmark_id)

	if not is_balanced(s) then
		return
	end

	leave_tabstop(state)

	return mapcb(function()
		enter_tabstop()
	end)
end

local function expand_char(c)
	local buf = get_current_buf()
	local snippets = buf_snippets[buf]

	local cbs = snippet_callbacks_by_key[snippets][c]
	if not cbs then
		return
	end

	local row, col = unpack(win_get_cursor(0))
	local opts = { buf = buf, row = row, col = col }

	for _, cb in ipairs(cbs) do
		local result = cb(opts)
		if result then
			local start_col = result.start_col or col
			local start_row = result.start_row or (row - 1)
			local end_col = result.end_col or col
			local end_row = result.end_row or (row - 1)
			local body = result.body
			local env = result.env or {}

			if type(body) == 'table' then
				body = join_lines(body)
			end

			body = require('snippets.textmate').parse(body)

			return mapcb(function()
				buf_set_text(buf, start_row, start_col, end_row, end_col, {})
				expand(buf, start_row, start_col, body, env)
			end)
		end
	end
end

local function handle_key(c)
	return jump_char(c) or expand_char(c) or c
end

local function handle_insert_enter(opts)
	local buf = opts.buf
	local row, col = unpack(win_get_cursor(0))

	local snippets = get_snippets(buf, row, col)

	if buf_snippets[buf] == snippets then
		return
	end

	buf_snippets[buf] = snippets

	local function set(mode, c)
		if fn.maparg(c, mode) ~= '' then
			return
		end
		local plug_key = '<Plug>(_snippets-' .. fn.char2nr(c) .. ')'
		keymap(mode, plug_key, '', {
			expr = true,
			noremap = true,
			callback = function()
				return handle_key(c)
			end,
		})
		buf_keymap(
			buf,
			mode,
			c,
			(mode == 'i' and '<C-G>U' or '') .. plug_key,
			{ noremap = true }
		)
	end

	local function set_is(c)
		set('i', c)
		set('s', c)
	end

	for c in pairs(snippet_callbacks_by_key[snippets]) do
		set_is(c)
	end

	for _, c in ipairs(jump_chars) do
		set_is(c)
	end
end

autocmd('InsertEnter', {
	group = group,
	callback = handle_insert_enter,
})

autocmd('BufUnload', {
	group = group,
	callback = function(opts)
		local buf = opts.buf
		buf_snippets[buf] = nil
	end,
})

local function keymap_is(...)
	keymap('i', ...)
	keymap('s', ...)
end

keymap_is(plug_callback, '', {
	callback = function()
		_G._snippets_callback()
	end,
})

return {
	jump = jump,
	expand = expand,
	handle_key = handle_key,
	_handle_insert_enter = handle_insert_enter,
}
