local api = vim.api
local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn

local buf_keymap = api.nvim_buf_set_keymap
local buf_user_command = api.nvim_buf_create_user_command
local autocmd = api.nvim_create_autocmd

local group = api.nvim_create_augroup('qf', { clear = false })
local ns = api.nvim_create_namespace('qf')

local buf_qf = {}
local buf_qe = {}

local function trigger_quickfix_changed()
	api.nvim_exec_autocmds('User', {
		pattern = 'QuickFixChanged',
		modeline = false,
	})
end

local function buf_set_lines_and_clear_undo(buf, lines)
	local bo = bo[buf]
	local saved_undolevels = bo.undolevels
	bo.undolevels = -1
	api.nvim_buf_set_lines(buf, 0, -1, true, lines)
	bo.undolevels = saved_undolevels
end

local function buf_is_hidden(buf)
	return fn.bufwinnr(buf) == -1
end

local function buf_unload(buf)
	cmd(buf .. 'bunload!')
end

local function buf_edit(buf)
	api.nvim_buf_call(buf, function()
		cmd('edit!')
	end)
end

local function buf_reload(buf)
	if buf_is_hidden(buf) then
		buf_unload(buf)
	else
		buf_edit(buf)
	end
end

local function make_bufnames()
	return setmetatable({ [-1] = '', [0] = '' }, {
		__index = function(t, k)
			local s = fn.bufname(k)
			t[k] = s
			return s
		end,
	})
end

local function get_current_item()
	local buf = api.nvim_get_current_buf()
	local qf = buf_qf[buf]
	local line = api.nvim_get_current_line()
	return assert(qf.line2item[line], 'no item under cursor')
end

local function retain(buf, predicate)
	local qf = buf_qf[buf]
	local line2item = qf.line2item
	local lines = api.nvim_buf_get_lines(buf, 0, -1, true)
	for i = #lines, 1, -1 do
		local line = lines[i]
		local item = line2item[line]
		if not predicate(item) then
			api.nvim_buf_set_lines(buf, i - 1, i, true, {})
		end
	end
end

local function highlight_row(buf, row)
	api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	if row == 0 then
		return
	end

	api.nvim_buf_call(buf, function()
		api.nvim_win_set_cursor(0, { row, 0 })
	end)

	api.nvim_buf_set_extmark(buf, ns, row - 1, 0, {
		line_hl_group = 'QuickFixLine',
	})
end

local function highlight_idx(buf)
	local qf = buf_qf[buf]
	local idx = qf.idx
	local row = 0

	if bo[buf].modified then
		local lines = api.nvim_buf_get_lines(buf, 0, -1, true)
		local line2item = qf.line2item

		for i, line in ipairs(lines) do
			local item = line2item[line]
			if item and item.idx == idx then
				row = i
				break
			end
		end
	else
		row = idx
	end

	highlight_row(buf, row)
end

local function qf2line(item, bufnames)
	local lnum, col, end_col = item.lnum, item.col, item.end_col

	local s = ''
	if lnum > 0 and col > 0 and end_col > 0 then
		s = string.format('%d col %d-%d', lnum, col, end_col)
	elseif lnum > 0 and col > 0 then
		s = string.format('%d col %d', lnum, col)
	elseif lnum > 0 then
		s = string.format('%d', lnum)
	end

	return string.format(
		'%s|%s| %s',
		bufnames[item.bufnr],
		s,
		string.sub(item.text, string.find(item.text, '%S') or 1)
	)
end

local function buf_qf_id(buf)
	local s = api.nvim_buf_get_name(buf)
	local id = tonumber(string.match(s, 'q[fe]://(%d+)'))
	return id
end

local function is_qf_list_same(a, b)
	return a.id == b.id and a.changedtick == b.changedtick
end

local function handle_quickfix_changed()
	for buf, cur in pairs(buf_qf) do
		local id = assert(buf_qf_id(buf))
		local qf = fn.getqflist({ id = id, changedtick = true, idx = 0 })

		if is_qf_list_same(cur, qf) then
			if cur.idx ~= qf.idx then
				cur.idx = qf.idx
				highlight_idx(buf)
			end
		else
			buf_reload(buf)
		end
	end

	for buf, cur in pairs(buf_qe) do
		local id = assert(buf_qf_id(buf))
		local qf = fn.getqflist({ id = id, changedtick = true })

		if not is_qf_list_same(cur, qf) then
			buf_reload(buf)
		end
	end
end

local function proxy_cmd(opts)
	for buf in pairs(buf_qf) do
		bo[buf].buftype = 'quickfix'
	end

	local a, b = string.match(opts.name, '(.)(.*)')
	local ok, msg = pcall(api.nvim_cmd, {
		cmd = string.lower(a) .. b,
		count = opts.count ~= -1 and opts.count or nil,
		bang = opts.bang,
		args = opts.fargs,
		mods = opts.smods,
	}, {})

	for buf in pairs(buf_qf) do
		local bo = bo[buf]
		bo.buftype = 'acwrite'
		bo.modifiable = true
	end

	if not ok then
		msg = string.match(msg, '^Vim[^:]*:(.*)') or msg
		api.nvim_echo({ { msg, 'ErrorMsg' } }, true, {})
		return false
	end

	trigger_quickfix_changed()

	if bo.buftype == 'quickfix' then
		bo.bufhidden = 'wipe'
		cmd.Qf()
	end

	return true
end

local function stack_cmd()
	cmd.edit('qf://')
	bo.bufhidden = 'unload'
end

local function list_cmd(opts)
	cmd.edit(fn.fnameescape('qf://' .. opts.count))
end

local function do_global(pat, text, bang)
	local buf = api.nvim_get_current_buf()
	local re = vim.regex(pat)
	retain(buf, function(item)
		return item.valid == 0 or (not re:match_str(text(item))) == bang
	end)
end

local function global_cmd(opts)
	local pat = opts.args

	if pat == '' then
		pat = fn.getreg('/')
	end

	do_global(pat, function(item)
		return item.text
	end, opts.bang == (opts.name == 'G'))
end

local function global_file_cmd(opts)
	local bufnames = make_bufnames()
	local pat = opts.args

	if pat == '' then
		pat = fn.getreg('/')
	else
		pat = fn.glob2regpat(pat)
	end

	do_global(pat, function(item)
		return bufnames[item.bufnr]
	end, opts.bang == (opts.name == 'Gf'))
end

local function edit_cmd(opts)
	local id = opts.count

	if id == 0 then
		id = buf_qf_id(0) or id
	end

	cmd.edit('qe://' .. id)
end

local function go_to_item()
	local pos = api.nvim_win_get_cursor(0)
	cmd.update()
	api.nvim_win_set_cursor(0, pos)
	local item = get_current_item()
	cmd.Cc({ count = item.idx })
end

local function delete_current_file()
	local buf = api.nvim_get_current_buf()
	local current = get_current_item()
	retain(buf, function(item)
		return item.bufnr ~= current.bufnr
	end)
end

local function read_qf_autocmd(opts)
	local buf = opts.buf

	local bo = bo[buf]
	bo.swapfile = false
	bo.modeline = false
	bo.buftype = 'acwrite'

	if opts.match == 'qf://' then
		bo.filetype = 'qfstack'

		local lines = {}
		local i = 1

		while true do
			local qf = fn.getqflist({ id = 0, nr = i, title = true })

			if qf.id == 0 then
				break
			end

			table.insert(lines, string.format('qf://%d\t%s', qf.id, qf.title))

			i = i + 1
		end

		buf_set_lines_and_clear_undo(buf, lines)
		highlight_row(buf, fn.getqflist({ nr = 0 }).nr)

		buf_keymap(buf, 'n', '<CR>', '', {
			nowait = true,
			expr = true,
			callback = function()
				local nr = api.nvim_win_get_cursor(0)[1]
				vim.schedule(function()
					cmd.Chistory({ count = nr })
				end)
				return '0gf'
			end,
		})

		return
	end

	bo.filetype = 'qf'

	local id = assert(buf_qf_id(buf))
	local qf = fn.getqflist({ id = id, all = true })

	local bufnames = make_bufnames()
	local lines = {}
	local line2item = {}

	for i, item in ipairs(qf.items) do
		item.idx = i
		local line = qf2line(item, bufnames)
		line2item[line] = item
		table.insert(lines, line)
	end

	buf_set_lines_and_clear_undo(buf, lines)

	qf.line2item = line2item
	buf_qf[buf] = qf

	highlight_idx(buf)

	buf_user_command(buf, 'G', global_cmd, {
		nargs = '*',
		bang = true,
		desc = 'Keep items matching display text',
	})
	buf_user_command(buf, 'V', global_cmd, {
		nargs = '*',
		bang = true,
		desc = 'Same as :G!',
	})

	buf_user_command(buf, 'Gf', global_file_cmd, {
		nargs = '*',
		bang = true,
		desc = 'Keep items matching file',
	})
	buf_user_command(buf, 'Vf', global_file_cmd, {
		nargs = '*',
		bang = true,
		desc = 'Same as :Gf!',
	})

	buf_keymap(buf, 'n', '<CR>', '', {
		nowait = true,
		callback = go_to_item,
		desc = 'Display item',
	})

	buf_keymap(buf, 'n', '<Plug>(quickfix-delete-file)', '', {
		expr = true,
		callback = function()
			_G._quickfix_repeat = delete_current_file
			vim.o.operatorfunc = 'v:lua._quickfix_repeat'
			return 'g@0'
		end,
		desc = 'Remove all items from file',
	})

	buf_keymap(buf, 'n', 'df', '<Plug>(quickfix-delete-file)', {
		nowait = true,
	})
end

local function write_qf_autocmd(opts)
	local buf = opts.buf

	local lines = api.nvim_buf_get_lines(buf, 0, -1, true)

	if opts.match == 'qf://' then
		assert(#lines == 1 and lines[1] == '')
		fn.setqflist({}, 'f')
		bo.modified = false
		return
	end

	local qf = buf_qf[buf]

	local new_items = {}
	local new_idx = math.max(1, qf.idx - 1)

	for i, line in ipairs(lines) do
		local item = qf.line2item[line]
		if item.idx == qf.idx then
			new_idx = i
		end
		item.idx = i
		table.insert(new_items, item)
	end

	assert(fn.setqflist({}, 'r', {
		id = qf.id,
		items = new_items,
		idx = new_idx,
	}) ~= -1)

	local new_qf = fn.getqflist({ id = qf.id, changedtick = true })
	qf.changedtick = new_qf.changedtick
	qf.idx = nil -- Force update.

	bo.modified = false
	api.nvim_echo({ { 'quickfix written', 'Normal' } }, false, {})

	trigger_quickfix_changed()
end

local function context_cmd(opts)
	vim.b.qf_context = opts.count
	cmd.edit()
end

local function read_qe_autocmd(opts)
	local buf = opts.buf
	local id = buf_qf_id(buf)
	local qf = fn.getqflist({ id = id, all = true })
	local context = vim.b.qf_context or 0

	local buf_rows = {}

	for _, item in ipairs(qf.items) do
		if item and item.valid == 1 then
			local buf, row = item.bufnr, item.lnum
			buf_rows[buf] = buf_rows[buf] or {}
			buf_rows[buf][row] = true
		end
	end

	local items = {}

	for buf, rows in pairs(buf_rows) do
		for row in pairs(rows) do
			table.insert(items, { buf = buf, row = row })
		end
	end

	local bufnames = make_bufnames()

	table.sort(items, function(a, b)
		if a.buf ~= b.buf then
			return bufnames[a.buf] < bufnames[b.buf]
		end
		return a.row < b.row
	end)

	local bo = bo[buf]
	bo.swapfile = false
	bo.modeline = false
	bo.buftype = 'acwrite'
	bo.filetype = 'qe'

	local lines = {}
	local index2row = {}
	local prev_buf

	for i, item in ipairs(items) do
		local buf, row = item.buf, item.row

		if buf ~= prev_buf then
			prev_buf = buf
			fn.bufload(buf)
		end

		local start_row = math.max(0, row - 1 - context)

		index2row[i] = #lines + row - 1 - start_row

		for _, line in
			ipairs(api.nvim_buf_get_lines(buf, start_row, row + context, false))
		do
			table.insert(lines, line)
		end

		if context > 0 then
			table.insert(lines, '')
		end
	end

	buf_set_lines_and_clear_undo(buf, lines)

	api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local extmark2item = {}

	for i, item in ipairs(items) do
		local extmark_id = api.nvim_buf_set_extmark(buf, ns, index2row[i], 0, {
			virt_text = {
				{ bufnames[item.buf], 'qfFileName' },
				{ '|', 'qfSeparator' },
				{ tostring(item.row), 'qfLineNr' },
				{ '|', 'qfSeparator' },
				{ ' ', 'Normal' },
			},
			virt_text_pos = 'inline',
			right_gravity = false,
			invalidate = true,
		})
		extmark2item[extmark_id] = item
	end

	buf_qe[buf] = {
		id = qf.id,
		changedtick = qf.changedtick,
		extmark2item = extmark2item,
	}

	buf_keymap(buf, 'n', '<CR>', '', {
		nowait = true,
		callback = function()
			local row = api.nvim_win_get_cursor(0)[1] - 1
			local extmarks = api.nvim_buf_get_extmarks(
				buf,
				ns,
				{ row, 0 },
				{ row, 0 },
				{ details = true }
			)

			for _, extmark in ipairs(extmarks) do
				local extmark_id, _, _, details = unpack(extmark)

				if not details.invalid then
					local item = buf_qe[buf].extmark2item[extmark_id]
					local bufname = fn.bufname(item.buf)
					cmd(string.format('pedit +%d %s', item.row, fn.fnameescape(bufname)))
					return
				end
			end
		end,
		desc = 'Preview line',
	})

	buf_user_command(buf, 'Qcontext', context_cmd, {
		count = true,
		desc = 'Set number of quickfix context lines',
	})
end

local function write_qe_autocmd(opts)
	local buf = opts.buf
	local extmark2item = buf_qe[buf].extmark2item

	local num_changes = 0
	local num_buffers = 0
	local seen_buffers = {}

	local lines = api.nvim_buf_get_lines(buf, 0, -1, true)
	local extmarks = api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })

	for _, extmark in ipairs(extmarks) do
		local extmark_id, row, _, details = unpack(extmark)

		if not details.invalid then
			local new_line = lines[row + 1]

			local item = extmark2item[extmark_id]
			local buf, row = item.buf, item.row
			local line = api.nvim_buf_get_lines(buf, row - 1, row, true)[1]

			if line ~= new_line then
				api.nvim_buf_set_lines(buf, row - 1, row, true, { new_line })

				num_changes = num_changes + 1
				if not seen_buffers[buf] then
					seen_buffers[buf] = true
					num_buffers = num_buffers + 1
				end
			end
		end
	end

	bo.modified = false

	local s = num_changes == 0 and '--No changes--'
		or string.format(
			'%d %s changed in %d %s',
			num_changes,
			num_changes == 1 and 'line' or 'lines',
			num_buffers,
			num_buffers == 1 and 'buffer' or 'buffers'
		)
	api.nvim_echo({ { s, 'Normal' } }, true, {})
end

local function cmdpost_autocmd(opts)
	local qf = fn.getqflist({ size = true })

	vim.schedule(function()
		if qf.size == 0 then
			cmd.Cclose()
			api.nvim_echo({ { 'empty error list', 'Normal' } }, false, {})
		else
			cmd('botright Copen')
			cmd.Cfirst()
		end
	end)

	trigger_quickfix_changed()
end

autocmd('BufWriteCmd', {
	group = group,
	pattern = 'qf://*',
	nested = true,
	callback = write_qf_autocmd,
})

autocmd('BufUnload', {
	group = group,
	pattern = 'qf://*',
	callback = function(opts)
		buf_qf[opts.buf] = nil
	end,
})

autocmd('BufWriteCmd', {
	group = group,
	pattern = 'qe://*',
	nested = true,
	callback = write_qe_autocmd,
})

autocmd('BufUnload', {
	group = group,
	pattern = 'qe://*',
	callback = function(opts)
		buf_qe[opts.buf] = nil
	end,
})

autocmd('User', {
	group = group,
	pattern = 'QuickFixChanged',
	nested = true,
	callback = function()
		handle_quickfix_changed()
	end,
})

autocmd('QuitPre', {
	group = group,
	nested = true,
	callback = function()
		cmd.Cclose()
	end,
})

return {
	cmdpost_autocmd = cmdpost_autocmd,
	edit_cmd = edit_cmd,
	list_cmd = list_cmd,
	proxy_cmd = proxy_cmd,
	read_qe_autocmd = read_qe_autocmd,
	read_qf_autocmd = read_qf_autocmd,
	stack_cmd = stack_cmd,
}
