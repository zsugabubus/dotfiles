local api, cmd = vim.api, vim.cmd
local ns = api.nvim_create_namespace('colorcolors')
local byte, sub = string.byte, string.sub
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift
local _0, _9, HM, DT, RP, PC = byte '0', byte '9', byte '-', byte '.', byte ')', byte '%'
local has_hl_group = {}
local matcher

local function rgb_luminance(r, g, b)
	local function f(s)
		local c = s / 255
		if c <= 0.04045 then
			return c / 12.92
		else
			return math.pow((c + 0.055) / 1.055, 2.4)
		end
	end
	return
		0.2126 * f(r) +
		0.7152 * f(g) +
		0.0722 * f(b)
end

local function rgb_lstar(r, g, b)
	local y = rgb_luminance(r, g, b)
	if y <= 216 / 24389 then
		return y * 24389 / 27
	else
		return math.pow(y, 1 / 3) * 116 - 16
	end
end

-- https://stackoverflow.com/questions/596216/formula-to-determine-perceived-brightness-of-rgb-color
local function rgb_is_bright(r, g, b)
	return rgb_lstar(r, g, b) >= 50
end

local function u888_to_rgb(rgb)
	return
		rshift(rgb, 16),
		band(rshift(rgb, 8), 0xff),
		band(rgb, 0xff)
end

local function hex_to_rgb(hex)
	if #hex <= 4 then
		local function f(i)
			local k = tonumber(sub(hex, i, i), 16)
			return bor(lshift(k, 4), k)
		end
		return f(1), f(2), f(3)
	else
		local rgb = tonumber(sub(hex, 0, 6), 16)
		return u888_to_rgb(rgb)
	end
end

local function cube_color(i)
	return i == 0 and 0 or 0x37 + 0x28 * i
end

local function tcolor_to_rgb(tcolor)
	local i = tonumber(tcolor)
	if i < 16 then
		if i == 7 then
			return 0xc0, 0xc0, 0xc0
		elseif i == 8 then
			return 0x80, 0x80, 0x80
		end
		-- User palette
		local c = i < 8 and 0x80 or 0xff
		return
			band(i, 0x1) ~= 0 and c or 0,
			band(i, 0x2) ~= 0 and c or 0,
			band(i, 0x4) ~= 0 and c or 0
	elseif i < 16 + 6 * 6 * 6 then
		-- Cube colors
		i = i - 16
		return
			cube_color(math.floor(i / 36) % 6),
			cube_color(math.floor(i / 6) % 6),
			cube_color(i % 6)
	else
		-- Grey scale.
		i = i - (16 + 6 * 6 * 6)
		local c = 0x08 + 0x0a * i
		return c, c, c
	end
end


-- https://en.wikipedia.org/wiki/HSL_and_HSV
local function hsl_to_rgb(h, s, l)
	local a = s * math.min(l, 1 - l)
	local function f(n)
		local k = (n + h / 30) % 12
		local c = l - a * math.max(-1, math.min(k - 3, 9 - k, 1))
		return c * 255
	end
	return f(0), f(8), f(4)
end

local function rgb_highlight(r, g, b)
	local rgb = bor(lshift(r, 16), lshift(g, 8), b)
	-- Use this stupid name to avoid potential cost of string.format().
	local hl_group = '_' .. rgb
	if not has_hl_group[rgb] then
		has_hl_group[hl_group] = true
		local color = string.format('%02x%02x%02x', r, g, b)
		local other = rgb_is_bright(r, g, b) and '000000' or 'ffffff'
		cmd.highlight {
			hl_group,
			'guibg=#' .. color,
			'guifg=#' .. other
		}
	end
	return hl_group
end

local function hex_digit(s, i)
	local c = bor(byte(s, i), 0x20)
	return c - (
		c < 0x60
		-- c - '0'
		and 48
		-- c - 'a' + 10
		or 87
	)
end

local function hex_byte(s, i)
	local x = hex_digit(s, i)
	return bor(lshift(x, 4), x)
end

local function hex2_byte(s, i)
	local hi, lo = hex_digit(s, i), hex_digit(s, i + 1)
	return bor(lshift(hi, 4), lo)
end

local function expect_number(s, i)
	if i == nil then
		return
	end
	local m = i + 100
	local c
	while true do
		c = byte(s, i)
		if not c then
			return
		end
		if (_0 <= c and c <= _9) or c == DT or c == HM then
			break
		end
		i = i + 1
		if m < i then
			return
		end
	end
	 local j = i
	 repeat
		 i = i + 1
		 c = byte(s, i)
	until not (c and _0 <= c and c <= _9 or c == DT or c == HM)
	local n = tonumber(sub(s, j, i - 1))
	if not n then
		return
	end
	return i, n
end

local function expect_percentage(s, i, one)
	local i, number = expect_number(s, i)
	if i == nil or number < 0 then
		return
	end

	local unit = byte(s, i)
	if
		-- "%"
		unit == 0x25
	then
		number = one * number / 100
		i = i + 1
	end

	if number > one then
		return
	end

	return i, number
end

local function expect_angle(s, i)
	local i, number = expect_number(s, i)
	if i == nil then
		return
	end

	local unit = byte(s, i)
	if
		-- "deg"
		unit == 0x64
	then
		-- Default, do nothing.
		i = i + 3
	elseif
		-- "grad"
		unit == 0x67
	then
		number = number * 360 / 400
		i = i + 4
	elseif
		-- "rad"
		unit == 0x72
	then
		number = number * 180 / math.pi
		i = i + 3
	elseif
		-- "turn"
		unit == 0x74
	then
		number = number * 360
		i = i + 4
	end

	return i, number
end

local function expect_end(s, i)
	if i == nil then
		return
	end
	local m = i + 100
	while (byte(s, i) or RP) ~= RP do
		i = i + 1
		if m < i then
			return
		end
	end
	return i
end

function build_matcher()
	local ffi = require 'ffi'
	local Matcher = require 'colorcolors.matcher'

	local m = Matcher:new({
		ignore_case = true,
	})

	ffi.cdef [[
	struct named_color {
		uint8_t len;
		uint8_t r, g, b;
	};
	]]
	local NamedColor = ffi.typeof('struct named_color')

	do
		local pre = m:P(nil, ' \t=:"\',(')
		for name, u888 in pairs(api.nvim_get_color_map()) do
			local val = ffi.new(NamedColor)
			val.len = #name
			val.r, val.g, val.b = u888_to_rgb(u888)
			m:A(m:S(pre, name), val)
		end
	end

	do
		local pre = m:C(nil, '-')
		for name, hex in pairs(require 'colorcolors.tailwind') do
			local val = ffi.new(NamedColor)
			val.len = #name
			val.r, val.g, val.b = hex_to_rgb(hex)
			m:A(m:S(pre, name), val)
		end
	end

	m:A(m:NP(m:S(nil, '#'), 3, 'a-f0-9'), '#rgb')
	m:A(m:NP(m:S(nil, '#'), 6, 'a-f0-9'), '#rrggbb')
	m:A(m:NP(m:S(nil, '0x'), 6, 'a-f0-9'), '0xrrggbb')

	-- FIXME: Matcher cannot handle patterns because it assumes _path is known at
	-- compile time for a node to build _other. #a... -> hex OR (junk)aqua?
	-- Currently it sees a _path like "#aaaaaa", re-feeds "aaaaaa" and computers
	-- _other to be root as nothing handles "aaaaaa". However this node can be
	-- reach via lot's of different pathes (\x{6}), that really is not computable
	-- at compile time (that's why patterns are used), so we would backtrack
	-- length - 1 (i.e. 5) bytes in input stream, reset to _root and "compute"
	-- _other dynamically. NOTE: This simple "backtracking" based on subtraction
	-- can only work if all _paths leading to node has the same length, otherwise
	-- some kind of state would have to be maintained. It seems okay, at most
	-- Matcher is not that generic but it is perfect for us.
	--[[
	m:A(m:C(m:NP(m:C(nil, '"'), 6, 'a-f0-9'), '"'), '"rrggbb"')
	m:A(m:C(m:NP(m:C(nil, "'"), 6, 'a-f0-9'), "'"), '"rrggbb"')
	]]

	m:A(m:P(m:S(nil, 'color'), '0-9'), 'color0')
	m:A(m:P(m:S(nil, 'colour'), '0-9'), 'colour0')

	do
		local pre = m:P(nil, ' \t:,(')
		m:A(m:S(pre, 'rgb('), 'rgb()')
		m:A(m:S(pre, 'rgba('), 'rgba()')
		m:A(m:S(pre, 'hsl('), 'hsl()')
		m:A(m:S(pre, 'hsla('), 'hsla()')
	end

	return m:build()
end

local function highlight_line(buffer, lnum, line, col, end_col)
	matcher(
		line,
		1,
		function(s, i, d)
			local r, g, b, from, to
			if type(d) == 'cdata' then
				r, g, b, from, to = d.r, d.g, d.b, i - 1 - d.len, i - 1
			elseif d == '#rgb' or d == 'rgb' then
				r, g, b, from, to =
					hex_byte(s, i - 3),
					hex_byte(s, i - 2),
					hex_byte(s, i - 1),
					i - 1 - #d, i - 1
			elseif d == '#rrggbb' or d == '0xrrggbb' then
				r, g, b, from, to =
					hex2_byte(s, i - 6),
					hex2_byte(s, i - 4),
					hex2_byte(s, i - 2),
					i - 1 - #d, i - 1
			elseif d == '"rrggbb"' then
				r, g, b, from, to =
					hex2_byte(s, i - 7),
					hex2_byte(s, i - 5),
					hex2_byte(s, i - 3),
					i - #d, i - 2
			elseif d == 'rgb()' or d == 'rgba()' then
				from = i - #d
				i, r = expect_percentage(s, i, 255)
				i, g = expect_percentage(s, i, 255)
				i, b = expect_percentage(s, i, 255)
				i = expect_end(s, i)
				if not i then
					return
				end
				to = i
			elseif d == 'hsl()' or d == 'hsla()' then
				local hue, saturation, lightness
				from = i - #d
				i, hue = expect_angle(s, i)
				i, saturation = expect_percentage(s, i, 1)
				i, lightness = expect_percentage(s, i, 1)
				i = expect_end(s, i)
				if not i then
					return
				end
				to = i
				r, g, b = hsl_to_rgb(hue, saturation, lightness)
			elseif d == 'color0' or d == 'colour0' then
				local n
				from, to, n = i - 1 - #d, expect_number(s, i - 1)
				if not n then
					return
				end
				to = to - 1
				r, g, b = tcolor_to_rgb(n)
			end

			local hl_group = rgb_highlight(r, g, b)
			api.nvim_buf_add_highlight(buffer, ns, hl_group, lnum, from, to)
			return i
		end
	)
end

local function highlight_lines(buffer, start_lnum, end_lnum, start_col, end_col)
	api.nvim_buf_clear_namespace(buffer, ns, start_lnum, end_lnum)
	local lines = api.nvim_buf_get_lines(buffer, start_lnum, end_lnum, false)

	-- local start = os.clock()
	for i, line in ipairs(lines) do
		highlight_line(buffer, start_lnum + i - 1, line, start_col, end_col)
	end
	-- print('elapsed', os.clock() - start, vim.inspect(stat):gsub("\n", ''))
end

function attach_to_buffer(buffer)
	matcher = matcher or build_matcher()

	highlight_lines(buffer, 0, -1, 0, 999999)

	api.nvim_buf_attach(
		buffer,
		false,
		{
			on_reload = function(_, buffer)
				highlight_lines(buffer, 0, -1, 0, 999999)
			end,
			on_lines = function(_, buffer, changedtick, firstline, lastline, new_lastline)
				local start_lnum, end_lnum  = firstline, math.max(lastline, new_lastline)
				highlight_lines(buffer, start_lnum, end_lnum, 0, 999999)
			end,
			on_detach = function()
				api.nvim_buf_clear_namespace(buffer, ns, 0, -1)
				-- api.nvim_del_autocmd(autocmd)
			end
		}
	)
end

api.nvim_create_autocmd(
	{'BufWinEnter'},
	{
		buffer = buffer,
		callback = function()
			-- White lie.
			vim.defer_fn(function()
				attach_to_buffer(api.nvim_get_current_buf())
			end, 1)
		end
	}
)
