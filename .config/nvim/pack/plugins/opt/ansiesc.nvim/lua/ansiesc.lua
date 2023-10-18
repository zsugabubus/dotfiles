local M = {}
local ns = vim.api.nvim_create_namespace('ansiesc')
local hl_cache = {}

local function index2hex(i)
	local r, g, b
	if i < 16 then
		if i == 7 then
			r, g, b = 0xc0, 0xc0, 0xc0
		elseif i == 8 then
			r, g, b = 0x80, 0x80, 0x80
		else
			local c = i < 8 and 0x80 or 0xff

			local function f(a)
				return bit.band(i, a) ~= 0 and c or 0
			end

			r, g, b = f(1), f(2), f(4)
		end
	elseif i < 16 + 6 * 6 * 6 then
		i = i - 16

		local function f(a)
			local k = math.floor(i / a) % 6
			if k == 0 then
				return 0
			else
				return 0x37 + 0x28 * k
			end
		end

		r, g, b = f(36), f(6), f(1)
	else
		i = i - (16 + 6 * 6 * 6)
		local c = 0x08 + 0x0a * i
		r, g, b = c, c, c
	end
	return string.format('#%02x%02x%02x', r, g, b)
end

local function parse_sgr(s)
	local params = {}

	string.gsub(s, '%d+', function(n)
		table.insert(params, tonumber(n))
	end)

	-- Default.
	if #params == 0 then
		params[1] = 0
	end

	return params
end

local function parse_sgr_color(params, i)
	if params[i] == 2 then
		return i + 4, string.format(
			'#%02x%02x%02x',
			params[i + 1],
			params[i + 2],
			params[i + 3]
		)
	elseif params[i] == 5 then
		return i + 2, index2hex(params[i + 1])
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
			pen.fg = index2hex(Ps - 30)
		elseif Ps == 38 then
			i, pen.fg = parse_sgr_color(params, i)
		elseif Ps == 39 then
			pen.fg = nil
		elseif 40 <= Ps and Ps <= 47 then
			pen.bg = index2hex(Ps - 40)
		elseif Ps == 48 then
			i, pen.bg = parse_sgr_color(params, i)
		elseif Ps == 49 then
			pen.bg = nil
		elseif Ps == 58 then
			i, pen.sp = parse_sgr_color(params, i)
		elseif 90 <= Ps and Ps <= 97 then
			pen.bg = index2hex(8 + (Ps - 90))
		elseif 100 <= Ps and Ps <= 107 then
			pen.bg = index2hex(8 + (Ps - 100))
		end
	end

	return pen
end

local function add_highlight(buffer, lnum, col_start, col_end, pen)
	if col_start == col_end or vim.tbl_isempty(pen) then
		return
	end

	local hl_group = string.format(
		'_ansiesc_%s_%s_%s_%s%s%s%s',
		pen.fg and string.sub(pen.fg, 2) or '',
		pen.bg and string.sub(pen.bg, 2) or '',
		pen.sp and string.sub(pen.sp, 2) or '',
		pen.bold and 'b' or '',
		pen.italic and 'i' or '',
		pen.underline and 'u' or '',
		pen.reverse and 'r' or ''
	)
	if not hl_cache[hl_group] then
		hl_cache[hl_group] = true
		vim.api.nvim_set_hl(0, hl_group, pen)
	end

	vim.api.nvim_buf_add_highlight(buffer, ns, hl_group, lnum, col_start, col_end)
end

function M.highlight_buffer(buffer)
	local pen = {}

	local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
	for lnum, line in ipairs(lines) do
		local starts = {}
		local sgrs = {}
		local original = line

		do
			local start = 1

			while true do
				local i, j, s = string.find(line, '\x1b%[([0-9;:]*)m', start)
				if s == nil then
					break
				end

				-- Make it 0-based.
				table.insert(starts, i - 1)
				table.insert(sgrs, s)

				line = (string.sub(line, 1, i - 1) .. string.sub(line, j + 1))
				start = i
			end

			if line ~= original then
				vim.api.nvim_buf_set_lines(buffer, lnum - 1, lnum, true, { line })
			end
		end

		do
			local start = 0

			for i, stop in ipairs(starts) do
				add_highlight(buffer, lnum - 1, start, stop, pen)
				start = stop

				local params = parse_sgr(sgrs[i])
				pen = apply_sgr(pen, params)
			end

			add_highlight(buffer, lnum - 1, start, -1, pen)
		end
	end
end

vim.api.nvim_create_autocmd('Colorscheme', {
	callback = function()
		for hl_group in pairs(hl_cache) do
			local _, _, fg, bg, sp, b, i, u, r = string.find(
				hl_group,
				'_ansiesc_([^_]*)_([^_]*)_([^_]*)_(b?)(i?)(u?)(r?)'
			)
			local hl = {
				fg = fg ~= '' and '#' .. fg or nil,
				bg = bg ~= '' and '#' .. bg or nil,
				sp = sp ~= '' and '#' .. sp or nil,
				bold = b ~= '',
				italic = i ~= '',
				underline = u ~= '',
				reverse = r ~= '',
			}
			vim.api.nvim_set_hl(0, hl_group, hl)
		end
	end,
})

return M
