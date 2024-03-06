local api = vim.api
local fn = vim.fn

local strwidth = fn.strdisplaywidth

local M = {}

function M.align(opts)
	local buf = opts.buf or 0
	local start_lnum = assert(opts.start_lnum)
	local end_lnum = assert(opts.end_lnum)
	local pat = opts.pattern or vim.pesc(opts.char)
	local align = assert(opts.align)
	local fill = opts.fill or ' '
	local margin_left, margin_right = unpack(opts.margin or { 1, 1 })
	local count = opts.count or math.huge

	local fill_width = strwidth(fill)

	local all_parts = {}
	local changes = {}
	local offsets = {}
	local cols = {}

	local function align_to(align_col, extra_n, col)
		assert(col <= align_col)
		if fill_width == 1 then
			return align_col + extra_n, align_col + extra_n - col
		else
			col = strwidth(fill, col)
			local n = math.ceil((align_col - col) / fill_width) + extra_n
			return col + n * fill_width, n
		end
	end

	local function add_change(index, offset, old_len, new_len)
		local n = new_len - old_len
		if n < 0 then
			-- Delete.
			table.insert(changes, { index, offset, offset + -n * #fill, 0 })
		elseif n > 0 then
			-- Insert.
			table.insert(changes, { index, offset, offset, n })
		end
	end

	local split_pat =
		string.format('(.-)(%s*)(%s)(%s*)', vim.pesc(fill), pat, vim.pesc(fill))
	local lines = api.nvim_buf_get_lines(buf, start_lnum - 1, end_lnum, true)
	for _, line in ipairs(lines) do
		local parts = {}

		local trail_text = string.gsub(
			line,
			split_pat,
			function(text, left, sep, right)
				if #parts >= count * 4 then
					return nil
				end
				table.insert(parts, text)
				table.insert(parts, #left / #fill)
				table.insert(parts, sep)
				table.insert(parts, #right / #fill)
				return ''
			end
		)
		table.insert(parts, trail_text)

		table.insert(all_parts, parts)
		table.insert(offsets, 0)
	end

	local k = 1
	local start_col = 0
	while true do
		local empty = true
		for _, parts in ipairs(all_parts) do
			local text = parts[k]
			if text and text ~= '' then
				empty = false
				break
			end
		end

		local align_col = 0

		for i, parts in ipairs(all_parts) do
			local text, left, sep = parts[k], parts[k + 1], parts[k + 2]
			if text then
				local col = start_col
				col = col + strwidth(text, col)

				if align == 'left' and left then
					local n = empty and left or margin_left
					col = col + strwidth(string.rep(fill, n), col)
					col = col + strwidth(sep, col)
				end

				cols[i] = col
				align_col = math.max(align_col, col)
			end
		end

		local end_col

		for i, parts in ipairs(all_parts) do
			local text, left, sep, right =
				parts[k], parts[k + 1], parts[k + 2], parts[k + 3]
			if left then
				local col = cols[i]
				local eol = k + 4 == #parts and parts[k + 4] == ''

				local new_left = empty and left or margin_left
				local new_right = eol and right or margin_right

				if align == 'right' then
					end_col, new_left = align_to(align_col, new_left, col)
					end_col = end_col + strwidth(sep, end_col)
				elseif not eol then
					end_col, new_right = align_to(align_col, new_right, col)
				end

				local offset = offsets[i]
				add_change(i, offset + #text, left, new_left)
				add_change(i, offset + #text + left * #fill + #sep, right, new_right)
				offsets[i] = offset + #text + #sep + (left + right) * #fill
			end
		end

		if not end_col then
			break
		end

		if align == 'right' then
			end_col = end_col + strwidth(string.rep(fill, margin_right), end_col)
		end

		k = k + 4
		start_col = end_col
	end

	for i = #changes, 1, -1 do
		local index, start_col, end_col, new_len = unpack(changes[i])
		local lnum = start_lnum + index - 1
		api.nvim_buf_set_text(
			buf,
			lnum - 1,
			start_col,
			lnum - 1,
			end_col,
			{ string.rep(fill, new_len) }
		)
	end

	api.nvim_echo({
		{
			string.format('%d lines aligned', end_lnum - start_lnum + 1),
			'Normal',
		},
	}, false, {})
end

return M
