local api = vim.api
local fn = vim.fn
local uv = vim.loop

local get_lines = api.nvim_buf_get_lines
local schedule = vim.schedule
local set_extmark = api.nvim_buf_set_extmark
local uv_is_active = uv.is_active
local uv_timer_start = uv.timer_start

local M = {}

local ADDED = {
	sign_text = '+',
	sign_hl_group = 'GitSignAdd',
}

local CHANGED = {
	sign_text = '~',
	sign_hl_group = 'GitSignChange',
}

local DELETED = {
	sign_text = '-',
	sign_hl_group = 'GitSignDelete',
}

local LIMIT_1 = {
	limit = 1,
}

local a_buf, b_buf
local attached = {}
local ns = api.nvim_create_namespace('git.sign')
local should_update
local timer = uv.new_timer()

local function detach()
	a_buf = nil
	b_buf = nil
end

local function clear_signs()
	for _, buf in ipairs(api.nvim_list_bufs()) do
		api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	end
end

local diff_opts = {
	on_hunk = function(_, a_count, b_row, b_count)
		b_row = b_row - 1
		if b_count == 0 then
			set_extmark(b_buf, ns, b_row, 0, DELETED)
		else
			for row = b_row, b_row + b_count - 1 do
				set_extmark(b_buf, ns, row, 0, a_count == 0 and ADDED or CHANGED)
			end
		end
	end,
	ignore_cr_at_eol = true,
}

local function update()
	if not api.nvim_buf_is_valid(a_buf) or not api.nvim_buf_is_valid(b_buf) then
		detach()
		return
	end

	api.nvim_buf_clear_namespace(b_buf, ns, 0, -1)

	if api.nvim_buf_get_option(a_buf, 'filetype') == 'giterror' then
		return
	end

	local a = table.concat(get_lines(a_buf, 0, -1, true), '\n')
	local b = table.concat(get_lines(b_buf, 0, -1, true), '\n')
	vim.diff(a, b, diff_opts)
end

local function timer_callback()
	if should_update then
		should_update = false
		schedule(update)
	else
		timer:stop()
	end
end

local attach_opts = {
	on_lines = function(_, buf, _, start_row, _, end_row)
		if a_buf ~= buf and b_buf ~= buf then
			return true
		end

		if not uv_is_active(timer) then
			if
				a_buf == buf
				or #api.nvim_buf_get_extmarks(
						b_buf,
						ns,
						{ start_row, 0 },
						{ end_row, 0 },
						LIMIT_1
					)
					== 0
			then
				schedule(update)
			else
				should_update = true
			end
		else
			should_update = true
		end

		local timeout = api.nvim_get_mode().mode == 'n' and 50 or 1500
		uv_timer_start(timer, timeout, 0, timer_callback)
	end,
	on_detach = function(_, buf)
		attached[buf] = nil
	end,
}

local function buf_attach(buf)
	if attached[buf] then
		return
	end
	attached[buf] = true
	api.nvim_buf_attach(buf, false, attach_opts)
end

local function attach_to_current_buf()
	if vim.bo.buftype ~= '' then
		return
	end

	local bufname = api.nvim_buf_get_name(0)
	if bufname == '' or string.find(bufname, '://', 1, true) then
		return
	end

	local Repository = require('git.repository')

	local repo = Repository.await(Repository.from_current_buf())
	if not repo.work_tree then
		detach()
		return
	end

	should_update = false
	timer:stop()

	local git_name = string.format(
		'git://@:%s',
		string.sub(fn.expand('%:p'), #repo.work_tree + 2)
	)

	a_buf = fn.bufnr(git_name, true)
	b_buf = api.nvim_get_current_buf()

	fn.bufload(a_buf)

	buf_attach(a_buf)
	buf_attach(b_buf)
end

function M.is_enabled()
	return a_buf ~= nil
end

function setup_highlights()
	local hl = vim.api.nvim_set_hl
	hl(0, 'GitSignAdd', {
		default = true,
		link = 'DiffAdd',
	})
	hl(0, 'GitSignChange', {
		default = true,
		link = 'DiffChange',
	})
	hl(0, 'GitSignDelete', {
		default = true,
		link = 'DiffDelete',
	})
end

function M.toggle(enable)
	if enable == nil then
		enable = not M.is_enabled()
	end

	local group = api.nvim_create_augroup('git.sign', {})
	clear_signs()
	detach()

	if not enable then
		return
	end

	api.nvim_create_autocmd('BufEnter', {
		group = group,
		nested = true,
		callback = attach_to_current_buf,
	})

	api.nvim_create_autocmd('ColorScheme', {
		group = group,
		callback = setup_highlights,
	})

	setup_highlights()
	attach_to_current_buf()
end

return M
