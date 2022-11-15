local M = {}
local api = vim.api
local ns = api.nvim_create_namespace('ansiesc')
local hl_cache = {}

local function termcolor(i)
	local r, g, b
	if i < 16 then
		if i == 7 then
			r, g, b = 0xc0, 0xc0, 0xc0
		elseif i == 8 then
			r, g, b = 0x80, 0x80, 0x80
		else
			local c = i < 8 and 0x80 or 0xff

			function f(a)
				return bit.band(i, a) ~= 0 and c or 0
			end

			r, g, b = f(1), f(2), f(4)
		end
	elseif i < 16 + 6 * 6 * 6 then
		i = i - 16

		function f(a)
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

local function apply_sgr(hl, Ps)
	local i = 1

	local function parse_color()
		local color
		if Ps[i] == 2 then
			color = string.format(
				'#%02x%02x%02x',
				Ps[i + 1],
				Ps[i + 2],
				Ps[i + 3]
			)
			i = i + 4
		elseif Ps[i] == 5 then
			color = termcolor(Ps[i + 1])
			i = i + 2
		end
		return color
	end

	while i <= #Ps do
		local attr = Ps[i]
		i = i + 1
		if attr == 0 then
			hl = {}
		elseif attr == 1 then
			hl.bold = true
		elseif attr == 3 then
			hl.italic = true
		elseif attr == 4 then
			hl.underline = true
		elseif attr == 7 then
			hl.reverse = true
		elseif attr == 9 then
			hl.strikethrough = true
		elseif attr == 21 then
			hl.bold = nil
		elseif attr == 22 then
			hl.bold = nil
		elseif attr == 23 then
			hl.italic = nil
		elseif attr == 24 then
			hl.underline = nil
		elseif attr == 27 then
			hl.reverse = nil
		elseif 30 <= attr and attr <= 37 then
			hl.fg = termcolor(attr - 30)
		elseif attr == 38 then
			hl.fg = parse_color()
		elseif attr == 39 then
			hl.fg = nil
		elseif 40 <= attr and attr <= 47 then
			hl.bg = termcolor(attr - 40)
		elseif attr == 48 then
			hl.bg = parse_color()
		elseif attr == 49 then
			hl.bg = nil
		elseif attr == 58 then
			hl.sp = parse_color()
		elseif 90 <= attr and attr <= 97 then
			hl.bg = termcolor(8 + (attr - 90))
		elseif 100 <= attr and attr <= 107 then
			hl.bg = termcolor(8 + (attr - 100))
		end
	end

	return hl
end

local function apply_highlight(buffer, lnum, start, stop, hl)
	if start == stop or vim.tbl_isempty(hl) then
		return
	end

	local hl_group = string.format(
		'_ansiesc_%s_%s_%s_%s%s%s%s',
		hl.fg and string.sub(hl.fg, 2) or '',
		hl.bg and string.sub(hl.bg, 2) or '',
		hl.sp and string.sub(hl.sp, 2) or '',
		hl.bold and 'b' or '',
		hl.italic and 'i' or '',
		hl.underline and 'u' or '',
		hl.reverse and 'r' or ''
	)
	if not hl_cache[hl_group] then
		hl_cache[hl_group] = true
		api.nvim_set_hl(0, hl_group, hl)
	end
	api.nvim_buf_add_highlight(buffer, ns, hl_group, lnum, start, stop)
end

local function parse_sgr(s)
	local t = {}
	string.gsub(s, '%d+', function(attr)
		t[#t + 1] = tonumber(attr)
	end)
	-- Default.
	if #t == 0 then
		t[1] = 0
	end
	return t
end

function M.highlight_buffer(buffer)
	local hl = {}

	local lines = api.nvim_buf_get_lines(buffer, 0, -1, false)
	for lnum, line in ipairs(lines) do
		local t = {}
		local text = line

		do
			local start = 1
			while true do
				local i, j, str = string.find(text, '\x1b%[([0-9;:]*)m', start)
				if i == nil then
					break
				end

				t[#t + 1] = i
				t[#t + 1] = str

				text = string.sub(text, 1, i - 1) .. string.sub(text, j + 1)
				start = i
			end
			if text ~= line then
				api.nvim_buf_set_lines(buffer, lnum - 1, lnum, true, {text})
			end
		end

		do
			local start = 0
			for i = 0, #t / 2 - 1 do
				local stop = t[i * 2 + 1] - 1
				apply_highlight(buffer, lnum - 1, start, stop, hl)
				start = stop

				local Ps = parse_sgr(t[i * 2 + 2])
				hl = apply_sgr(hl, Ps)
			end
			apply_highlight(buffer, lnum - 1, start, #text, hl)
		end
	end
end

api.nvim_create_autocmd(
	{'Colorscheme'},
	{
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
				api.nvim_set_hl(0, hl_group, hl)
			end
		end
	}
)

return M
