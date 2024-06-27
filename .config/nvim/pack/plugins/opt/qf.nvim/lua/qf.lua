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

local function buf_set_lines_and_clear_undo(buf, lines)
	local bo = bo[buf]
	local saved_undolevels = bo.undolevels
	bo.undolevels = -1
	api.nvim_buf_set_lines(buf, 0, -1, true, lines)
	bo.undolevels = saved_undolevels
end

local function set_highlights()
	api.nvim_set_hl(0, 'qeLineNr', { link = 'LineNr', default = true })
	api.nvim_set_hl(0, 'qeHeader', { link = 'Normal', default = true })
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

local function make_bufnames()
	return setmetatable({ [-1] = '', [0] = '' }, {
		__index = function(t, k)
			local s = fn.bufname(k)
			t[k] = s
			return s
		end,
	})
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

local function update_qf(buf)
	local s = api.nvim_buf_get_name(buf)
	local id = assert(tonumber(string.match(s, 'qf://(%d+)')))

	local cur = buf_qf[buf]
	local qf = fn.getqflist({ id = id, changedtick = true, idx = 0 })

	if cur and cur.id == qf.id and cur.changedtick == qf.changedtick then
		if cur.idx ~= qf.idx then
			cur.idx = qf.idx
			highlight_idx(buf)
		end
		return
	end

	qf = fn.getqflist({ id = id, all = true })

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
	bo[buf].modified = false

	qf.line2item = line2item
	buf_qf[buf] = qf

	highlight_idx(buf)
end

local function update_qf_all()
	for buf in pairs(buf_qf) do
		update_qf(buf)
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

	api.nvim_exec_autocmds('User', {
		pattern = 'QuickFixChanged',
		modeline = false,
	})

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
	bo.bufhidden = 'unload'
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
		local s = api.nvim_buf_get_name(0)
		id = string.match(s, 'qf://(%d+)') or id
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

		api.nvim_buf_set_lines(buf, 0, -1, true, lines)
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

	update_qf(buf)

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

	update_qf(buf)
end

local function read_qe_autocmd(opts)
	local s = opts.match
	local buf = opts.buf
	local id = assert(tonumber(string.match(s, 'qe://(%d+)')))
	local qf = fn.getqflist({ id = id, all = true })

	local buf_rows = {}
	local max_row = 0

	for _, item in ipairs(qf.items) do
		if item and item.valid == 1 then
			local buf, row = item.bufnr, item.lnum
			buf_rows[buf] = buf_rows[buf] or {}
			buf_rows[buf][row] = true
			max_row = math.max(max_row, row)
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

	buf_qe[buf] = items

	local bo = bo[buf]
	bo.swapfile = false
	bo.modeline = false
	bo.buftype = 'acwrite'

	local lines = {}
	local prev_buf

	for _, item in ipairs(items) do
		local buf, row = item.buf, item.row
		if buf ~= prev_buf then
			prev_buf = buf
			fn.bufload(buf)
		end
		local line = api.nvim_buf_get_lines(buf, row - 1, row, true)[1]
		table.insert(lines, line)
	end

	buf_set_lines_and_clear_undo(buf, lines)

	api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local row_format = string.format('%%%dd ', #('' .. max_row))
	local prev_buf

	for i, item in ipairs(items) do
		if item.buf ~= prev_buf then
			prev_buf = item.buf

			api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_lines = {
					{
						{ string.format('%s:', bufnames[item.buf]), 'qeHeader' },
					},
				},
				virt_lines_above = true,
			})
		end

		api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
			virt_text = {
				{ string.format(row_format, item.row), 'qeLineNr' },
			},
			virt_text_pos = 'inline',
			right_gravity = false,
		})
	end

	buf_keymap(buf, 'n', '<CR>', '', {
		nowait = true,
		callback = function()
			local i = api.nvim_win_get_cursor(0)[1]
			local item = items[i]
			local bufname = bufnames[item.buf]
			cmd(string.format('pedit +%d %s', item.row, fn.fnameescape(bufname)))
		end,
		desc = 'Preview line',
	})

	set_highlights()
end

local function write_qe_autocmd(opts)
	local buf = opts.buf
	local items = buf_qe[buf]

	local changes = 0
	local lines = api.nvim_buf_get_lines(buf, 0, -1, true)
	assert(#lines == #items)

	for i, item in ipairs(items) do
		local buf, row = item.buf, item.row
		local old_line = api.nvim_buf_get_lines(buf, row - 1, row, true)[1]
		local new_line = lines[i]
		if old_line ~= new_line then
			api.nvim_buf_set_lines(buf, row - 1, row, true, { new_line })
			changes = changes + 1
		end
	end

	bo.modified = false
	local s = string.format('%d changes committed', changes)
	api.nvim_echo({ { s, 'Normal' } }, false, {})
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
	update_qf_all()
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
		update_qf_all()
	end,
})

autocmd('QuitPre', {
	group = group,
	nested = true,
	callback = function()
		cmd.Cclose()
	end,
})

autocmd('ColorScheme', {
	group = group,
	nested = true,
	callback = function()
		set_highlights()
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
