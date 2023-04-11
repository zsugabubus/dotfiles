local M = {}
local enabled = false
local timer = require 'luv'.new_timer()
local cword
local wins = {}

local function clear_win(win)
	vim.fn.matchdelete(vim.w[win].hicword_id, win)
end

local function clear()
	for _, win in ipairs(wins) do
		pcall(clear_win, win)
	end
end

local function update()
	local cur_cword = vim.fn.expand('<cword>')
	if cword == cur_cword then
		return
	end
	cword = cur_cword

	clear()

	if #cword < 1 or 100 < #cword then
		return
	end

	local pattern = string.format([[\<\V%s\>]], string.gsub(cword, [[\]], [[\\]]))
	for _, win in ipairs(wins) do
		vim.w[win].hicword_id = vim.fn.matchadd(
			'Cword',
			pattern,
			-1,
			vim.w[win].hicword_id or -1,
			{
				window = win,
			}
		)
	end
end

local schedule_update = vim.schedule_wrap(update)

local function setup_highlight()
	vim.api.nvim_set_hl(0, 'Cword', {
		underline = 1,
		default = 1,
	})
end

local function update_wins()
	clear()
	wins = vim.api.nvim_tabpage_list_wins(0)
	cword = nil
	update()
end

function M.toggle(enable)
	if enable == nil then
		enable = not enabled
	end
	enabled = enable

	local group = vim.api.nvim_create_augroup('hicword', {})

	if not enabled then
		clear()
		return
	end

	vim.api.nvim_create_autocmd('CursorMoved', {
		group = group,
		callback = function()
			if vim.fn.reg_executing() ~= '' then
				return
			end

			local timeout = vim.g.cword_timeout or 75
			if timeout <= 0 then
				schedule_update()
			else
				if not timer:is_active() then
					schedule_update()
				end
				timer:stop()
				timer:start(timeout, 0, schedule_update)
			end
		end,
	})

	vim.api.nvim_create_autocmd({'WinNew', 'WinClosed', 'WinEnter'}, {
		group = group,
		callback = function()
			vim.schedule(update_wins)
		end,
	})

	vim.api.nvim_create_autocmd('Colorscheme', {
		group = group,
		callback = setup_highlight,
	})

	setup_highlight()
	update_wins()
end

function M.is_enabled()
	return enabled
end

return M
