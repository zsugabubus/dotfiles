local ffi = require('ffi')

local api = vim.api
local config = vim.g.colors or {}
local format = string.format
local max = math.max
local min = math.min
local schedule = vim.schedule
local set_hl = api.nvim_set_hl

local autocmd = api.nvim_create_autocmd
local buf_clear_ns = api.nvim_buf_clear_namespace
local buf_is_valid = api.nvim_buf_is_valid
local buf_line_count = api.nvim_buf_line_count
local buf_set_extmark = api.nvim_buf_set_extmark
local get_hl_id_by_name = api.nvim_get_hl_id_by_name

local HEADER = [[
struct highlight {
	int start_col, end_col;
	uint32_t color;
};

int nvim_buf_get_color_matches(int, int, struct highlight *, size_t);
int nvim_is_bright_background_color(uint32_t);
]]
pcall(ffi.cdef, HEADER)

local ns = api.nvim_create_namespace('colors')

local library_path = config.library_path
	or (vim.fn.stdpath('data') .. '/libnvim_plugin_colors.so')
local hls_len = config.max_highlights_per_line or 100
local hls = ffi.new('struct highlight[?]', hls_len)
local max_lines_to_highlight = config.max_lines_to_highlight or 2000
local debug = config.debug
local auto_attach = config.auto_attach

local lib
local attached_bufs = {}
local hl_cache
local extmark_opts = { end_col = nil, hl_group = nil, undo_restore = false }

local function get_contrast_fg(bg_color)
	local bright_bg = lib.nvim_is_bright_background_color(bg_color) ~= 0
	return bright_bg and '#000000' or '#ffffff'
end

local function create_hl_group(bg_color)
	local hl_name = '_colors_' .. bg_color
	set_hl(0, hl_name, {
		bg = format('#%06x', bg_color),
		fg = get_contrast_fg(bg_color),
	})
	return get_hl_id_by_name(hl_name)
end

local function highlight_lines(buf, start_row, end_row)
	local start, count = debug and vim.loop.hrtime(), 0

	buf_clear_ns(buf, ns, start_row, end_row)

	for row = start_row, end_row - 1 do
		local n = lib.nvim_buf_get_color_matches(buf, row + 1, hls, hls_len)

		for i = 0, n - 1 do
			local m = hls[i]
			extmark_opts.end_col = m.end_col + 1
			extmark_opts.hl_group = hl_cache[m.color]
			buf_set_extmark(buf, ns, row, m.start_col, extmark_opts)
		end

		count = count + n
	end

	if start then
		print(
			format(
				'colors: %6d highlights on %5d-%5d (%5d) lines in %7.3fms',
				count,
				start_row,
				end_row,
				end_row - start_row,
				(vim.loop.hrtime() - start) / 1e6
			)
		)
	end
end

local function is_attached_to_buffer(buf)
	assert(buf ~= 0)
	return attached_bufs[buf] == true
end

local function attach_to_buffer(buf)
	local attached_bufs = attached_bufs

	assert(buf ~= 0)
	if attached_bufs[buf] then
		return
	end
	attached_bufs[buf] = true

	local start_row
	local end_row
	local scheduled

	local function commit()
		scheduled = false

		if buf_is_valid(buf) then
			local last_row = buf_line_count(buf)

			start_row = min(start_row, last_row)
			end_row = min(end_row, last_row)

			highlight_lines(buf, start_row, end_row)
		end

		start_row, end_row = math.huge, 0
	end

	local function reload()
		buf_clear_ns(buf, ns, 0, -1)

		start_row = 0
		end_row = max_lines_to_highlight

		commit()
	end

	assert(api.nvim_buf_attach(buf, false, {
		on_lines = function(_, buf, _, change_start, change_end, change_new_end)
			if not attached_bufs[buf] then
				return true
			end

			start_row = min(start_row, change_start)
			end_row = max(end_row, change_end, change_new_end)

			if not scheduled then
				scheduled = true
				schedule(commit)
			end
		end,
		on_reload = reload,
		on_detach = function(_, buf)
			attached_bufs[buf] = nil
		end,
	}))

	reload()
end

local function enter_buffer(buf)
	if auto_attach == false then
		return
	elseif type(auto_attach) == 'function' and not auto_attach(buf) then
		return
	end

	attach_to_buffer(buf)
end

local function detach_from_buffer(buf)
	assert(buf ~= 0)
	attached_bufs[buf] = nil
	schedule(function()
		pcall(buf_clear_ns, buf, ns, 0, -1)
	end)
end

local function reload()
	hl_cache = setmetatable({}, {
		__index = function(hl_cache, color)
			local hl_group = create_hl_group(color)
			hl_cache[color] = hl_group
			return hl_group
		end,
	})

	for buf in pairs(attached_bufs) do
		attached_bufs[buf] = nil
	end
	attached_bufs = {}

	for _, win in ipairs(api.nvim_list_wins()) do
		local buf = api.nvim_win_get_buf(win)

		-- Unloaded buffers hopefully handled by BufWinEnter.
		if api.nvim_buf_is_loaded(buf) then
			enter_buffer(buf)
		end
	end
end

local function get_rust_dir()
	return assert(vim.tbl_filter(function(x)
		return vim.endswith(x, 'colors.nvim/rust')
	end, api.nvim_get_runtime_file('rust', true))[1])
end

local function install_library()
	vim.cmd(
		format(
			'! set -x && cd -- %s && cargo build --release && mv -- target/release/libnvim_plugin_colors.so %s',
			vim.fn.shellescape(get_rust_dir()),
			vim.fn.shellescape(library_path)
		)
	)
end

local function load_library()
	lib = ffi.load(library_path)

	local group = api.nvim_create_augroup('colors', {})

	autocmd('BufWinEnter', {
		group = group,
		callback = function(opts)
			enter_buffer(opts.buf)
		end,
	})

	autocmd('ColorScheme', {
		group = group,
		callback = function()
			reload()
		end,
	})

	reload()
end

return {
	load_library = load_library,
	install_library = install_library,
	attach_to_buffer = attach_to_buffer,
	detach_from_buffer = detach_from_buffer,
	is_attached_to_buffer = is_attached_to_buffer,
	reload = reload,
}
