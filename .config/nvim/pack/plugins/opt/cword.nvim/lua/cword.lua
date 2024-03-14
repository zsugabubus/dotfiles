local api = vim.api
local fn = vim.fn

local M = {}

local enabled = false
local timer = vim.loop.new_timer()
local cword
local wins = {}

local function clear_win(win)
	fn.matchdelete(vim.w[win].cword_match_id, win)
end

local function clear()
	for _, win in ipairs(wins) do
		pcall(clear_win, win)
	end
end

local function update()
	local cur_cword = fn.expand('<cword>')
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
		local w = vim.w[win]
		w.cword_match_id =
			fn.matchadd('Cword', pattern, -1, w.cword_match_id or -1, {
				window = win,
			})
	end
end

local function timer_callback()
	vim.schedule(update)
end

local function setup_highlight()
	api.nvim_set_hl(0, 'Cword', {
		underline = true,
		default = true,
	})
end

local function update_wins()
	clear()
	wins = api.nvim_tabpage_list_wins(0)
	cword = nil
	update()
end

function M.toggle(b)
	if b == nil then
		b = not enabled
	end
	enabled = b

	local group = api.nvim_create_augroup('cword', {})

	if not enabled then
		clear()
		return
	end

	api.nvim_create_autocmd('CursorMoved', {
		group = group,
		callback = function()
			if fn.reg_executing() ~= '' then
				return
			end

			if not timer:is_active() then
				vim.schedule(update)
			end
			timer:start(100, 0, timer_callback)
		end,
	})

	api.nvim_create_autocmd({ 'WinNew', 'WinClosed', 'WinEnter' }, {
		group = group,
		callback = function()
			vim.schedule(update_wins)
		end,
	})

	api.nvim_create_autocmd('ColorScheme', {
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
