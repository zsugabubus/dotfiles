local api = vim.api

local M = {}

local hl_cache
local attached_bufs

local function load_library()
	local ffi = require('ffi')

	local hls_len = M.config.max_highlights_per_line

	local ns = api.nvim_create_namespace('colors')
	local group = api.nvim_create_augroup('colors', {})

	-- Silent re-definition errors.
	pcall(
		ffi.cdef,
		[[
struct highlight {
	int start_col, end_col;
	uint32_t color;
};

int nvim_buf_get_color_matches(int, int, struct highlight *, size_t);
int nvim_is_bright_background_color(uint32_t);
		]]
	)

	local lib = ffi.load(M.config.library_path)
	local hls = ffi.new('struct highlight[?]', hls_len)

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
		local last_row = api.nvim_buf_line_count(buf)
		start_row = math.min(start_row, last_row)
		end_row = math.min(end_row, last_row)

		local start, count = M.config.debug and vim.loop.hrtime(), 0

		api.nvim_buf_clear_namespace(buf, ns, start_row, end_row)

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

	local function attach_to_buffer(buf)
		if attached_bufs[buf] then
			return
		end
		attached_bufs[buf] = true

		local first_row
		local last_row
		local scheduled

		local function commit()
			scheduled = false
			if api.nvim_buf_is_valid(buf) then
				highlight_lines(buf, first_row, last_row)
			end
			first_row, last_row = math.huge, 0
		end

		local function reload()
			api.nvim_buf_clear_namespace(buf, ns, 0, -1)
			first_row = 0
			last_row = M.config.max_lines_to_highlight
			commit()
		end

		assert(api.nvim_buf_attach(buf, false, {
			on_lines = function(_, buf, _, start_row, end_row, new_end_row)
				if not attached_bufs[buf] then
					return true
				end
				first_row = math.min(first_row, start_row)
				last_row = math.max(last_row, end_row, new_end_row)
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

	local function reset()
		hl_cache = {}
		attached_bufs = {}
		for _, win in ipairs(api.nvim_list_wins()) do
			local buf = api.nvim_win_get_buf(win)
			-- Unloaded buffers hopefully handled by BufWinEnter.
			if vim.fn.bufloaded(buf) == 1 then
				attach_to_buffer(buf)
			end
		end
	end

	api.nvim_create_autocmd('BufWinEnter', {
		group = group,
		callback = function(opts)
			attach_to_buffer(opts.buf)
		end,
	})

	api.nvim_create_autocmd('ColorScheme', {
		group = group,
		callback = function()
			reset()
		end,
	})

	reset()
end

local function get_rust_dir()
	return assert(vim.tbl_filter(function(x)
		return vim.endswith(x, 'colors.nvim/rust')
	end, api.nvim_get_runtime_file('rust', true))[1])
end

function M.setup(opts)
	local default_config = {
		library_path = vim.fn.stdpath('data') .. '/libnvim_plugin_colors.so',
		max_lines_to_highlight = 2000,
		max_highlights_per_line = 100,
		debug = false,
	}

	M.config = setmetatable(opts or {}, { __index = default_config })

	for k, v in pairs(M.config) do
		local expected = type(rawget(default_config, k))
		if type(rawget(M.config, k)) ~= expected then
			error(
				string.format('invalid key: %s (should be a %s value)', k, expected)
			)
		end
	end

	api.nvim_create_user_command('ColorsInstall', function()
		vim.cmd(
			string.format(
				'! set -x && cd -- %s && cargo build --release && mv -- target/release/libnvim_plugin_colors.so %s',
				vim.fn.shellescape(get_rust_dir()),
				vim.fn.shellescape(M.config.library_path)
			)
		)
		load_library()
	end, {})

	load_library()
end

return M
