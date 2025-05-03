local api = vim.api
local bo = vim.bo
local config = vim.g.multisearch or {}
local fn = vim.fn
local go = vim.go

local autocmd = api.nvim_create_autocmd
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('multisearch', {})

local highlights = config.highlights or { 'Search' }
local very_magic = config.very_magic

local wins = {}
local patterns = {}

local function get_pattern(s)
	if s == '' then
		return ''
	end

	if go.smartcase and go.ignorecase and s:match('[A-Z]') then
		s = '\\C' .. s
	elseif go.ignorecase then
		s = '\\c' .. s
	end

	if very_magic then
		s = '\\v' .. s
	end

	return s
end

local function update()
	for win, win_patterns in pairs(wins) do
		for s, i in pairs(patterns) do
			if not win_patterns[s] then
				local hl_group = highlights[((i - 1) % #highlights) + 1]
				win_patterns[s] = fn.matchadd(hl_group, get_pattern(s), -1, -1, {
					window = win,
				})
			end
		end
		for s, match_id in pairs(win_patterns) do
			if not patterns[s] then
				pcall(fn.matchdelete, match_id, win)
				win_patterns[s] = nil
			end
		end
	end
end

user_command('MultiSearch', function()
	vim.cmd.edit('multisearch://')
end, {})

autocmd('BufReadCmd', {
	group = group,
	pattern = 'multisearch://',
	callback = function()
		local lines = {}
		for s, i in pairs(patterns) do
			lines[i] = s
		end
		api.nvim_buf_set_lines(0, 0, -1, true, lines)
		bo.buftype = 'acwrite'
		bo.modeline = false
	end,
})

autocmd('BufWriteCmd', {
	group = group,
	pattern = 'multisearch://',
	callback = function()
		patterns = {}
		update()
		for i, s in ipairs(api.nvim_buf_get_lines(0, 0, -1, true)) do
			patterns[s] = i
		end
		update()
		bo.modified = false
	end,
})

autocmd('WinNew', {
	group = group,
	callback = function()
		wins[api.nvim_get_current_win()] = {}
		update()
	end,
})

autocmd('WinClosed', {
	group = group,
	callback = function(opts)
		wins[tonumber(opts.match)] = nil
	end,
})

for _, win in ipairs(api.nvim_list_wins()) do
	wins[win] = {}
end
