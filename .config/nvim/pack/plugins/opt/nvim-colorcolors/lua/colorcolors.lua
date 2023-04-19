local M = {}
local ns = vim.api.nvim_create_namespace('colorcolors')
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift
local hl_cache = {}
local lib
local matcher
local attached = {}

local function load_library()
	local ffi = require 'ffi'

	local hdr = [[
enum type {
	T_NONE,
	T_NAMED,
	T_RGB,
	T_RRGGBB,
	T_RGB_FN,
	T_HSL_FN,
	T_HWB_FN,
	T_LAB_FN,
	T_LCH_FN,
	T_COLOR,
	T_SGR_8,
	T_SGR_BRIGHT_8,
	T_SGR_256,
	T_SGR_RGB,
};

struct rgb24 {
	uint8_t r, g, b;
};

struct highlight {
	size_t first, last;
	struct rgb24 color;
};

int rgb24_is_bright(struct rgb24 const *rgb24);
size_t match(char const *, size_t, struct highlight *, size_t);
]]
	ffi.cdef(hdr)

	local objdir = vim.fn.stdpath('cache')
	vim.fn.mkdir(objdir, 'p')
	local obj = string.format('%s/%s', objdir, 'colorcolors.so')

	local ok, lib = pcall(ffi.load, obj)
	if ok then
		return lib
	end

	local m
	do
		local spec = {}

		for name, u888 in pairs(vim.api.nvim_get_color_map()) do
			table.insert(spec, {name, bit.bor(bit.lshift(u888, 8), ffi.C.T_NAMED)})
		end
		for name, hex in pairs(require 'colorcolors.tailwind') do
			table.insert(spec, {'-' .. name, string.format('0x%s%02x', hex, ffi.C.T_NAMED)})
		end
		table.insert(spec, {'#[a-f0-9]{3}', ffi.C.T_RGB})
		table.insert(spec, {'#[a-f0-9]{6}', ffi.C.T_RRGGBB})
		table.insert(spec, {'0x[a-f0-9]{3}', ffi.C.T_RGB})
		table.insert(spec, {'0x[a-f0-9]{6}', ffi.C.T_RRGGBB})
		table.insert(spec, {'"[a-f0-9]{6}"', bit.bor(0x0100, ffi.C.T_RRGGBB)})
		table.insert(spec, {"'[a-f0-9]{6}'", bit.bor(0x0100, ffi.C.T_RRGGBB)})
		table.insert(spec, {"rgb(", ffi.C.T_RGB_FN})
		table.insert(spec, {"rgba(", ffi.C.T_RGB_FN})
		table.insert(spec, {"hsl(", ffi.C.T_HSL_FN})
		table.insert(spec, {"hsla(", ffi.C.T_HSL_FN})
		table.insert(spec, {"hwb(", ffi.C.T_HWB_FN})
		table.insert(spec, {"lab(", ffi.C.T_LAB_FN})
		table.insert(spec, {"lch(", ffi.C.T_LCH_FN})
		table.insert(spec, {'color[0-9]', ffi.C.T_COLOR})
		table.insert(spec, {'colour[0-9]', ffi.C.T_COLOR})
		table.insert(spec, {'[[;]3[0-7][;m]', ffi.C.T_SGR_8})
		table.insert(spec, {'[[;]4[0-7][;m]', ffi.C.T_SGR_8})
		table.insert(spec, {'[[;]9[0-7][;m]', ffi.C.T_SGR_BRIGHT_8})
		table.insert(spec, {'[[;]10[0-7][;m]', ffi.C.T_SGR_BRIGHT_8})
		table.insert(spec, {'[[;][34]8;5;[0-9]', ffi.C.T_SGR_256})
		table.insert(spec, {'[[;][34]8;2;[0-9]', ffi.C.T_SGR_RGB})

		local Matcher = require('colorcolors.matcher')
		m = Matcher:new({
			spec = spec,
			ignore_case = true,
		})
	end

	local src = vim.fn.tempname() .. '.c'
	local f = assert(io.open(src, 'w'))
	f:write [[
#include <assert.h>
#include <errno.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
]]
	f:write(hdr)
	f:write(('static uint16_t const K = %d;\n'):format(m.alphabet))
	f:write(('static uint16_t const S = %d;\n'):format(m.start))

	local function write_array(ty, nam, arr, n)
		f:write(('static %s const %s[] = {'):format(ty, nam))
		for i = 0, n - 1 do
			if i % 10 == 0 then
				f:write('\n\t')
			end
			f:write('0x')
			f:write(bit.tohex(arr[i]))
			f:write(',')
		end
		f:write('\n};\n')
	end

	for i = 0, m.states - 1 do
		m.accepts[i] = m.accepts[i] or ffi.C.T_NONE
	end
	write_array('uint32_t', 'ACCEPTS', m.accepts, m.states)
	write_array('uint8_t', 'CHARMAP', m.charmap, 256)
	write_array('uint16_t', 'TRANSITIONS', m.transitions, m.states * m.alphabet)

	f:write(require 'colorcolors.code')
	f:close()

	os.execute(string.format(
		'cc -shared -fPIC -O2 -o %s %s -lm -Wconversion -Wall -Wextra -Wshadow -ffast-math',
		obj,
		src
	))
	os.remove(src)

	return ffi.load(obj)
end

local function hls_iter(hls, i)
	if 0 < i then
		i = i - 1
		return i, hls[i]
	end
end

local function load_matcher()
	local ffi = require 'ffi'
	lib = load_library()
	local hls = ffi.new('struct highlight[?]', 1000)
	return function(s)
		local n = lib.match(s, #s, hls, 1000)
		return hls_iter, hls, n
	end
end

local function rgb2hl(rgb)
	local u888 = bor(lshift(rgb.r, 16), lshift(rgb.g, 8), rgb.b)
	local hl_group = '_' .. u888
	if hl_cache[u888] == nil then
		local color = string.format('#%06x', u888)
		local other = lib.rgb24_is_bright(rgb) ~= 0 and '#000000' or '#ffffff'
		hl_cache[u888] = other
		vim.api.nvim_set_hl(0, hl_group, {
			bg = color,
			fg = other,
		})
	end
	return hl_group
end

function M._reset_hls()
	for u888, other in pairs(hl_cache) do
		local hl_group = '_' .. u888
		local color = string.format('#%06x', u888)
		vim.api.nvim_set_hl(0, hl_group, {
			bg = color,
			fg = other,
		})
	end
end

local function highlight_line(buffer, lnum, line)
	local nvim_buf_add_highlight = vim.api.nvim_buf_add_highlight
	for _, hl in matcher(line) do
		nvim_buf_add_highlight(
			buffer,
			ns,
			rgb2hl(hl.color),
			lnum,
			bit.tobit(hl.first),
			bit.tobit(hl.last)
		)
	end
end

local function highlight_lines(buffer, start_lnum, end_lnum)
	-- Bug:
	--   dejawu = #ffff00
	--            HHHHHHH
	--   ^dwu
	--   dejawu = #ffff00
	--                   H
	--
	-- What probably happens is:
	-- (1) "on_lines" emitted.
	-- (2) Extmarks moved as they follow text changes.
	--
	-- Between (1) and (2) however we clear old extmarks and add new ones
	-- that already have correct positions so they should not be moved,
	-- obviously. Thus we must make sure highlight updating happens after (2) so
	-- it does not interfere with it.
	vim.schedule(function()
		if not pcall(vim.api.nvim_buf_clear_namespace, buffer, ns, start_lnum, end_lnum) then
			-- Buffer got deleted.
			return
		end
		local lines = vim.api.nvim_buf_get_lines(buffer, start_lnum, end_lnum, false)
		for i, line in ipairs(lines) do
			highlight_line(buffer, start_lnum + i - 1, line)
		end
	end)
end

local function detach_from_buffer(buffer)
	assert(0 < buffer)
	attached[buffer] = nil
	-- Maybe there is a pending highlight_lines() so we must make sure
	-- that we clear highlights after it finishes.
	vim.schedule(function()
		pcall(vim.api.nvim_buf_clear_namespace, buffer, ns, 0, -1)
	end)
end

local function attach_to_buffer(buffer)
	assert(0 < buffer)
	if attached[buffer] then
		return
	end
	attached[buffer] = true
	matcher = matcher or load_matcher()
	highlight_lines(buffer, 0, -1)

	vim.api.nvim_buf_attach(
		buffer,
		false,
		{
			on_reload = function(_, buffer)
				highlight_lines(buffer, 0, -1)
			end,
			on_lines = function(_, buffer, changedtick, firstline, lastline, new_lastline)
				if not attached[buffer] then
					return true
				end
				local start_lnum, end_lnum  = firstline, math.max(lastline, new_lastline)
				highlight_lines(buffer, start_lnum, end_lnum)
			end,
			on_detach = function(_, buffer)
				detach_from_buffer(buffer)
			end
		}
	)
end

function M.is_attached(buffer)
	assert(0 < buffer)
	return attached[buffer]
end

function M.toggle_buffer(buffer, attach)
	buffer = buffer or vim.api.nvim_get_current_buf()
	if attach == nil then
		attach = not M.is_attached(buffer)
	end
	if attach then
		attach_to_buffer(buffer)
	else
		detach_from_buffer(buffer)
	end
end

return M
