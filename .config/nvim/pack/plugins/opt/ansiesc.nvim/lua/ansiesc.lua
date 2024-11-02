local api = vim.api
local ipairs = ipairs
local next = next
local sbyte = string.byte
local sfind = string.find
local sformat = string.format
local sgsub = string.gsub
local smatch = string.match
local ssub = string.sub
local tclear = require('table.clear')
local tinsert = table.insert

local buf_add_highlight = api.nvim_buf_add_highlight
local buf_set_lines = api.nvim_buf_set_lines
local set_hl = api.nvim_set_hl

local ns = api.nvim_create_namespace('ansiesc')
local group = api.nvim_create_augroup('ansiesc', {})

local hl_cache = {}
local palette

local function is_default_pen(pen)
	return next(pen) == nil
end

local function pen_to_hl_group(pen)
	return sformat(
		'_ansiesc_%s_%s_%s_%s%s%s%s%s',
		pen.fg and ssub(pen.fg, 2) or '',
		pen.bg and ssub(pen.bg, 2) or '',
		pen.sp and ssub(pen.sp, 2) or '',
		pen.bold and 'b' or '',
		pen.italic and 'i' or '',
		pen.underline and 'u' or '',
		pen.reverse and 'r' or '',
		pen.strikethrough and 's' or ''
	)
end

local function hl_group_to_pen(hl_group)
	local fg, bg, sp, b, i, u, r, s =
		smatch(hl_group, '^_ansiesc_([^_]*)_([^_]*)_([^_]*)_(b?)(i?)(u?)(r?)(s?)$')
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
		set_hl(0, hl_group, pen)
	end

	buf_add_highlight(buffer, ns, hl_group, row, start_col, end_col)
end

local function make_ansi_parser()
	local start_cols = {}
	local sgrs = {}
	local offset

	local function f(i, sgr, j)
		tinsert(start_cols, i + offset)
		tinsert(sgrs, sgr)
		offset = offset - (j - i)
		return ''
	end

	return function(s)
		tclear(start_cols)
		tclear(sgrs)
		offset = -1
		return sgsub(s, '()\x1b%[([0-9;:]*)m()', f), start_cols, sgrs
	end
end

local function make_sgr_parser()
	local params = {}

	return function(s)
		tclear(params)
		local i = 1

		while true do
			local j = sfind(s, ';', i, true)
			if j then
				tinsert(params, j <= i and '0' or ssub(s, i, j - 1))
				i = j + 1
			else
				tinsert(params, i > #s and '0' or ssub(s, i))
				return params
			end
		end
	end
end

local function color(r, g, b)
	return sformat('#%02x%02x%02x', r, g, b)
end

local function get_palette()
	local palette = {}

	for _, x in ipairs({ { 0, 0xff }, { 0, 0xff } }) do
		for _, b in ipairs(x) do
			for _, g in ipairs(x) do
				for _, r in ipairs(x) do
					tinsert(palette, color(r, g, b))
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
		tinsert(cube, 0x37 + 0x28 * i)
	end

	for _, r in ipairs(cube) do
		for _, g in ipairs(cube) do
			for _, b in ipairs(cube) do
				tinsert(palette, color(r, g, b))
			end
		end
	end

	for i = 0, 23 do
		local c = 0x08 + 0x0a * i
		tinsert(palette, color(c, c, c))
	end

	return palette
end

local function get_palette_color(i)
	if not palette then
		palette = get_palette()
	end
	return palette[i + 1]
end

local function parse_sgr_color(params, i)
	if params[i] == '2' then
		return i + 4, color(params[i + 1], params[i + 2], params[i + 3])
	elseif params[i] == '5' then
		return i + 2, get_palette_color(params[i + 1])
	end
	return i, nil
end

local function apply_sgr(pen, params)
	local i = 1
	while i <= #params do
		local Ps = params[i]
		i = i + 1
		if Ps == '0' then
			tclear(pen)
		elseif Ps == '1' then
			pen.bold = true
		elseif Ps == '3' then
			pen.italic = true
		elseif Ps == '4' then
			pen.underline = true
		elseif Ps == '7' then
			pen.reverse = true
		elseif Ps == '9' then
			pen.strikethrough = true
		elseif Ps == '21' then
			pen.bold = nil
		elseif Ps == '22' then
			pen.bold = nil
		elseif Ps == '23' then
			pen.italic = nil
		elseif Ps == '24' then
			pen.underline = nil
		elseif Ps == '27' then
			pen.reverse = nil
		elseif
			Ps == '30'
			or Ps == '31'
			or Ps == '32'
			or Ps == '33'
			or Ps == '34'
			or Ps == '35'
			or Ps == '36'
			or Ps == '37'
		then
			pen.fg = get_palette_color(sbyte(Ps, 2) - 48)
		elseif Ps == '38' then
			i, pen.fg = parse_sgr_color(params, i)
		elseif Ps == '39' then
			pen.fg = nil
		elseif
			Ps == '40'
			or Ps == '41'
			or Ps == '42'
			or Ps == '43'
			or Ps == '44'
			or Ps == '45'
			or Ps == '46'
			or Ps == '47'
		then
			pen.bg = get_palette_color(sbyte(Ps, 2) - 48)
		elseif Ps == '48' then
			i, pen.bg = parse_sgr_color(params, i)
		elseif Ps == '49' then
			pen.bg = nil
		elseif Ps == '58' then
			i, pen.sp = parse_sgr_color(params, i)
		elseif
			Ps == '90'
			or Ps == '91'
			or Ps == '92'
			or Ps == '93'
			or Ps == '94'
			or Ps == '95'
			or Ps == '96'
			or Ps == '97'
		then
			pen.fg = get_palette_color(sbyte(Ps, 2) - 40)
		elseif
			Ps == '100'
			or Ps == '101'
			or Ps == '102'
			or Ps == '103'
			or Ps == '104'
			or Ps == '105'
			or Ps == '106'
			or Ps == '107'
		then
			pen.bg = get_palette_color(sbyte(Ps, 3) - 40)
		end
	end
	return pen
end

local parse_ansi = make_ansi_parser()
local parse_sgr = make_sgr_parser()

local function highlight_buffer(buffer)
	for row, line in ipairs(api.nvim_buf_get_lines(buffer, 0, -1, false)) do
		local line_without_sgr, start_cols, sgrs = parse_ansi(line)

		if line ~= line_without_sgr then
			buf_set_lines(buffer, row - 1, row, true, { line_without_sgr })

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
			set_hl(0, hl_group, pen)
		end
	end,
})

return {
	highlight_buffer = highlight_buffer,
}
