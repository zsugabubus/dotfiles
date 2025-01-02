local fn = vim.fn
local api = vim.api
local bo = vim.bo

local ns = api.nvim_create_namespace('cat')

local function join_lines(t)
	return table.concat(t, '\n')
end

local function from_bufname(s)
	local ranges = {}
	for x in s:sub(7):gmatch('[^,]+') do
		local buf, from, to = x:match('^(%d+):(%d*)%-(%d*)$')
		table.insert(ranges, {
			buf = tonumber(buf or x),
			start_row = (tonumber(from) or 1) - 1,
			end_row = tonumber(to) or -1,
		})
	end
	return ranges
end

local function to_bufname(ranges)
	local t = {}
	for _, x in ipairs(ranges) do
		if x.start_row == 0 and x.end_row == -1 then
			table.insert(t, x.buf)
		else
			table.insert(t, ('%d:%d-%d'):format(x.buf, x.start_row + 1, x.end_row))
		end
	end
	return 'cat://' .. table.concat(t, ',')
end

local function sorted(ranges)
	local t = {}
	for i = 1, #ranges do
		t[i] = i
	end
	table.sort(t, function(ai, bi)
		local x = ranges[ai]
		local y = ranges[bi]
		if x.buf == y.buf then
			return x.start_row > y.start_row
		end
		return x.buf < y.buf
	end)
	return t
end

local function is_overlapping(ranges)
	local ris = sorted(ranges)
	for i = 2, #ris do
		local x = ranges[ris[i - 1]]
		local y = ranges[ris[i]]
		if x.buf == y.buf and (x.start_row < y.end_row or y.end_row == -1) then
			return true
		end
	end
	return false
end

local function handle_read_autocmd(opts)
	local n = 0
	local ranges = from_bufname(opts.match)

	local modifiable = true

	local saved_undolevels = bo.undolevels
	bo.undolevels = -1
	bo.swapfile = false
	bo.modeline = false
	bo.readonly = false
	bo.modifiable = true
	if is_overlapping(ranges) then
		bo.buftype = 'nowrite'
	else
		bo.buftype = 'acwrite'
	end

	api.nvim_buf_clear_namespace(0, ns, 0, -1)

	for i, x in ipairs(ranges) do
		fn.bufload(x.buf)

		if bo[x.buf].readonly then
			bo.readonly = true
		end

		if not bo[x.buf].modifiable then
			modifiable = false
		end

		if i == 1 then
			bo.filetype = bo[x.buf].filetype
		end

		local lines = api.nvim_buf_get_lines(x.buf, x.start_row, x.end_row, true)
		api.nvim_buf_set_lines(0, i == 1 and 0 or -1, -1, true, lines)

		if #ranges > 1 then
			api.nvim_buf_set_extmark(0, ns, n, 0, {
				virt_lines = { { { fn.bufname(x.buf), 'Normal' } } },
				virt_lines_above = true,
			})
		end

		n = n + #lines
	end

	bo.modifiable = modifiable
	bo.undolevels = saved_undolevels
end

local function handle_write_autocmd(opts)
	local n = 0
	local ranges = from_bufname(opts.match)
	local ris = sorted(ranges)

	local marks = #ranges == 1 and { { 0, 0, 0 } }
		or api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
	assert(#marks == #ranges)

	for i, ri in ipairs(ris) do
		local x = ranges[ri]

		local existing_lines =
			api.nvim_buf_get_lines(x.buf, x.start_row, x.end_row, true)
		local lines = api.nvim_buf_get_lines(
			0,
			marks[ri][2],
			(marks[ri + 1] or {})[2] or -1,
			true
		)

		local hunks = vim.diff(
			join_lines(existing_lines),
			join_lines(lines),
			{ result_type = 'indices' }
		)

		for k = #hunks, 1, -1 do
			local hunk = hunks[k]
			local offset = hunk[2] == 0 and 0 or -1
			local src_lines = vim.list_slice(lines, hunk[3], hunk[3] + hunk[4] - 1)
			api.nvim_buf_set_lines(
				x.buf,
				x.start_row + hunk[1] + offset,
				x.start_row + hunk[1] + hunk[2] + offset,
				true,
				src_lines
			)
			n = n + 1
		end

		local d = #lines - #existing_lines

		for j = i - 1, 1, -1 do
			local y = ranges[ris[j]]
			if x.buf ~= y.buf then
				break
			end
			assert(x.end_row ~= -1)
			assert(y.start_row >= x.end_row)
			y.start_row = y.start_row + d
			if y.end_row ~= -1 then
				y.end_row = y.end_row + d
			end
		end

		if x.end_row ~= -1 then
			x.end_row = x.end_row + d
		end
	end

	vim.cmd('keepalt file ' .. to_bufname(ranges))

	bo.modified = false

	if n == 0 then
		api.nvim_echo({ { '--No changes--', 'Normal' } }, false, {})
	else
		api.nvim_echo({
			{
				('%d %s written'):format(n, n == 1 and 'change' or 'changes'),
				'Normal',
			},
		}, true, {})
	end
end

return {
	handle_read_autocmd = handle_read_autocmd,
	handle_write_autocmd = handle_write_autocmd,
}
