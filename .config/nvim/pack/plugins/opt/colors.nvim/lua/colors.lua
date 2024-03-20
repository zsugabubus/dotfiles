local ffi = require('ffi')

local api = vim.api

local HEADER = [[
struct highlight {
	int start_col, end_col;
	uint32_t color;
};

int nvim_buf_get_color_matches(int, int, struct highlight *, size_t);
int nvim_is_bright_background_color(uint32_t);
]]

local ns = api.nvim_create_namespace('colors')

local library_path
local max_highlights_per_line
local max_lines_to_highlight
local debug
local is_buffer_enabled

local lib
local hls
local attached_bufs
local hl_cache

local function rgb2hl(color)
	local hl_group = '_' .. color

	if hl_cache[color] == nil then
		hl_cache[color] = true

		local is_bright = lib.nvim_is_bright_background_color(color) ~= 0

		api.nvim_set_hl(0, hl_group, {
			bg = string.format('#%06x', color),
			fg = is_bright and '#000000' or '#ffffff',
		})
	end

	return hl_group
end

local function highlight_lines(buf, start_row, end_row)
	local start, count = debug and vim.loop.hrtime(), 0

	api.nvim_buf_clear_namespace(buf, ns, start_row, end_row)

	local hls_len = max_highlights_per_line
	local add_highlight = api.nvim_buf_add_highlight

	for row = start_row, end_row - 1 do
		local n = lib.nvim_buf_get_color_matches(buf, row + 1, hls, hls_len)

		for i = 0, n - 1 do
			local m = hls[i]
			add_highlight(buf, ns, rgb2hl(m.color), row, m.start_col, m.end_col + 1)
		end

		count = count + n
	end

	if start then
		print(
			string.format(
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

		if api.nvim_buf_is_valid(buf) then
			local last_row = api.nvim_buf_line_count(buf)

			start_row = math.min(start_row, last_row)
			end_row = math.min(end_row, last_row)

			highlight_lines(buf, start_row, end_row)
		end

		start_row, end_row = math.huge, 0
	end

	local function reload()
		api.nvim_buf_clear_namespace(buf, ns, 0, -1)

		start_row = 0
		end_row = max_lines_to_highlight

		commit()
	end

	assert(api.nvim_buf_attach(buf, false, {
		on_lines = function(_, buf, _, change_start, change_end, change_new_end)
			if not attached_bufs[buf] then
				return true
			end

			start_row = math.min(start_row, change_start)
			end_row = math.max(end_row, change_end, change_new_end)

			if not scheduled then
				scheduled = true
				vim.schedule(commit)
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
	if is_buffer_enabled(buf) then
		attach_to_buffer(buf)
	end
end

local function detach_from_buffer(buf)
	assert(buf ~= 0)
	attached_bufs[buf] = nil
	vim.schedule(function()
		pcall(api.nvim_buf_clear_namespace, buf, ns, 0, -1)
	end)
end

local function reload()
	hl_cache = {}
	attached_bufs = {}

	for _, win in ipairs(api.nvim_list_wins()) do
		local buf = api.nvim_win_get_buf(win)

		-- Unloaded buffers hopefully handled by BufWinEnter.
		if api.nvim_buf_is_loaded(buf) then
			enter_buffer(buf)
		end
	end
end

local function create_autocmds()
	local group = api.nvim_create_augroup('colors', {})

	api.nvim_create_autocmd('BufWinEnter', {
		group = group,
		callback = function(opts)
			enter_buffer(opts.buf)
		end,
	})

	api.nvim_create_autocmd('ColorScheme', {
		group = group,
		callback = function()
			reload()
		end,
	})
end

local function get_rust_dir()
	return assert(vim.tbl_filter(function(x)
		return vim.endswith(x, 'colors.nvim/rust')
	end, api.nvim_get_runtime_file('rust', true))[1])
end

local function install_library()
	vim.cmd(
		string.format(
			'! set -x && cd -- %s && cargo build --release && mv -- target/release/libnvim_plugin_colors.so %s',
			vim.fn.shellescape(get_rust_dir()),
			vim.fn.shellescape(library_path)
		)
	)
end

local function load_library()
	lib = ffi.load(library_path)
	create_autocmds()
	reload()
end

local function create_user_commands()
	api.nvim_create_user_command('ColorsInstall', function()
		install_library()
		load_library()
	end, {})
end

local function setup(opts)
	opts = opts or {}

	library_path = opts.library_path
		or (vim.fn.stdpath('data') .. '/libnvim_plugin_colors.so')
	max_lines_to_highlight = opts.max_lines_to_highlight or 2000
	max_highlights_per_line = opts.max_highlights_per_line or 100
	debug = opts.debug
	is_buffer_enabled = opts.is_buffer_enabled or function()
		return true
	end

	pcall(ffi.cdef, HEADER)

	hls = ffi.new('struct highlight[?]', max_highlights_per_line)

	create_user_commands()
end

return {
	setup = setup,
	load_library = load_library,
	install_library = install_library,
	attach_to_buffer = attach_to_buffer,
	detach_from_buffer = detach_from_buffer,
	is_attached_to_buffer = is_attached_to_buffer,
	reload = reload,
}
