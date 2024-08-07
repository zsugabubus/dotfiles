local api = vim.api

local ns = api.nvim_create_namespace('ansiesc')
local group = api.nvim_create_augroup('ansiesc', {})

local hl_cache = {}
local palette

local function color(r, g, b)
	return string.format('#%02x%02x%02x', r, g, b)
end

local function get_palette()
	local palette = {}

	for _, x in ipairs({ { 0, 0xff }, { 0, 0xff } }) do
		for _, b in ipairs(x) do
			for _, g in ipairs(x) do
				for _, r in ipairs(x) do
					table.insert(palette, color(r, g, b))
				end
			end
		end
	end

	palette[7] = color(0xc0, 0xc0, 0xc0)
	palette[8] = color(0x80, 0x80, 0x80)

	for i = 1, 16 do
		palette[i] = vim.g['terminal_color_' .. (i - 1)] or palette[i]
	end

	local cube = { 0 }
	for i = 1, 5 do
		table.insert(cube, 0x37 + 0x28 * i)
	end

	for _, r in ipairs(cube) do
		for _, g in ipairs(cube) do
			for _, b in ipairs(cube) do
				table.insert(palette, color(r, g, b))
			end
		end
	end

	for i = 0, 23 do
		local c = 0x08 + 0x0a * i
		table.insert(palette, color(c, c, c))
	end

	return palette
end

local function get_palette_color(i)
	if not palette then
		palette = get_palette()
	end
	return palette[i + 1]
end

local function parse_sgr(s)
	local params = {}
	local i = 1

	while true do
		local j = string.find(s, ';', i, true)

		if not j then
			table.insert(params, tonumber(string.sub(s, i)) or 0)
			return params
		end

		table.insert(params, tonumber(string.sub(s, i, j - 1)) or 0)
		i = j + 1
	end
end

local function parse_sgr_color(params, i)
	if params[i] == 2 then
		return i + 4, color(params[i + 1], params[i + 2], params[i + 3])
	elseif params[i] == 5 then
		return i + 2, get_palette_color(params[i + 1])
	end
	return i, nil
end

local function apply_sgr(pen, params)
	local i = 1
	while i <= #params do
		local Ps = params[i]
		i = i + 1
		if Ps == 0 then
			pen = {}
		elseif Ps == 1 then
			pen.bold = true
		elseif Ps == 3 then
			pen.italic = true
		elseif Ps == 4 then
			pen.underline = true
		elseif Ps == 7 then
			pen.reverse = true
		elseif Ps == 9 then
			pen.strikethrough = true
		elseif Ps == 21 then
			pen.bold = nil
		elseif Ps == 22 then
			pen.bold = nil
		elseif Ps == 23 then
			pen.italic = nil
		elseif Ps == 24 then
			pen.underline = nil
		elseif Ps == 27 then
			pen.reverse = nil
		elseif 30 <= Ps and Ps <= 37 then
			pen.fg = get_palette_color(Ps - 30)
		elseif Ps == 38 then
			i, pen.fg = parse_sgr_color(params, i)
		elseif Ps == 39 then
			pen.fg = nil
		elseif 40 <= Ps and Ps <= 47 then
			pen.bg = get_palette_color(Ps - 40)
		elseif Ps == 48 then
			i, pen.bg = parse_sgr_color(params, i)
		elseif Ps == 49 then
			pen.bg = nil
		elseif Ps == 58 then
			i, pen.sp = parse_sgr_color(params, i)
		elseif 90 <= Ps and Ps <= 97 then
			pen.fg = get_palette_color(8 + (Ps - 90))
		elseif 100 <= Ps and Ps <= 107 then
			pen.bg = get_palette_color(8 + (Ps - 100))
		end
	end
	return pen
end

local function is_default_pen(pen)
	return next(pen) == nil
end

local function pen_to_hl_group(pen)
	return string.format(
		'_ansiesc_%s_%s_%s_%s%s%s%s%s',
		pen.fg and string.sub(pen.fg, 2) or '',
		pen.bg and string.sub(pen.bg, 2) or '',
		pen.sp and string.sub(pen.sp, 2) or '',
		pen.bold and 'b' or '',
		pen.italic and 'i' or '',
		pen.underline and 'u' or '',
		pen.reverse and 'r' or '',
		pen.strikethrough and 's' or ''
	)
end

local function hl_group_to_pen(hl_group)
	local fg, bg, sp, b, i, u, r, s = string.match(
		hl_group,
		'^_ansiesc_([^_]*)_([^_]*)_([^_]*)_(b?)(i?)(u?)(r?)(s?)$'
	)
	return {
		fg = fg ~= '' and '#' .. fg or nil,
		bg = bg ~= '' and '#' .. bg or nil,
		sp = sp ~= '' and '#' .. sp or nil,
		bold = b ~= '' or nil,
		italic = i ~= '' or nil,
		underline = u ~= '' or nil,
		reverse = r ~= '' or nil,
		strikethrough = s ~= '' or nil,
	}
end

local function add_highlight(buffer, row, start_col, end_col, pen)
	if start_col == end_col or is_default_pen(pen) then
		return
	end

	local hl_group = pen_to_hl_group(pen)
	if not hl_cache[hl_group] then
		hl_cache[hl_group] = true
		api.nvim_set_hl(0, hl_group, pen)
	end

	api.nvim_buf_add_highlight(buffer, ns, hl_group, row, start_col, end_col)
end

local function make_ansi_parser()
	local string_gsub = string.gsub

	local start_cols
	local sgrs
	local offset

	-- Creating a new closure on every line is expensive.
	local function f(i, sgr, j)
		table.insert(start_cols, i + offset)
		table.insert(sgrs, sgr)
		offset = offset - (j - i)
		return ''
	end

	return function(s)
		start_cols = {}
		sgrs = {}
		offset = -1
		return string_gsub(s, '()\x1b%[([0-9;:]*)m()', f), start_cols, sgrs
	end
end
local ansi_parse = make_ansi_parser()

local function highlight_buffer(buffer)
	for row, line in ipairs(api.nvim_buf_get_lines(buffer, 0, -1, false)) do
		local line_without_sgr, start_cols, sgrs = ansi_parse(line)

		if line ~= line_without_sgr then
			api.nvim_buf_set_lines(buffer, row - 1, row, true, { line_without_sgr })

			local pen = {}
			local start_col = 0

			for i, end_col in ipairs(start_cols) do
				add_highlight(buffer, row - 1, start_col, end_col, pen)
				start_col = end_col
				pen = apply_sgr(pen, parse_sgr(sgrs[i]))
			end

			add_highlight(buffer, row - 1, start_col, -1, pen)
		end
	end
end

api.nvim_create_autocmd('ColorScheme', {
	group = group,
	callback = function()
		palette = nil
		for hl_group in pairs(hl_cache) do
			local pen = hl_group_to_pen(hl_group)
			api.nvim_set_hl(0, hl_group, pen)
		end
	end,
})

return {
	highlight_buffer = highlight_buffer,
}
