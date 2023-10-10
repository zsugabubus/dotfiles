local api = vim.api
local autocmd = api.nvim_create_autocmd
local user_command = api.nvim_create_user_command
local group = api.nvim_create_augroup('tmux', {})

local function autoload_user_command(opts)
	return require('tmux')[opts.name](opts)
end

local function autoload_autocmd(opts)
	local name = opts.event .. '_' .. string.match(opts.match, '^tmux://([^/]*)')
	return require('tmux')[name](opts)
end

local function autoload_complete(prefix, cmdline)
	local name = vim.fn.fullcommand(string.match(cmdline, '([^ ]*)'))
		.. '_complete'
	return require('tmux')[name](prefix)
end

autocmd({ 'BufReadCmd', 'BufWriteCmd' }, {
	group = group,
	pattern = 'tmux://buffer/*',
	callback = autoload_autocmd,
})

autocmd('BufReadCmd', {
	group = group,
	pattern = { 'tmux://buffers', 'tmux://pane/*' },
	callback = autoload_autocmd,
})

user_command('Tsplitwindow', autoload_user_command, {
	-- :lcd and :tcd do not set process working directory.
	desc = 'Vim-aware tmux split-window',
})

user_command('Tbuffer', autoload_user_command, {
	nargs = 1,
	complete = autoload_complete,
	desc = 'Edit tmux buffer',
})
user_command('Tlistbuffers', autoload_user_command, {
	desc = 'List tmux buffers',
})

local opts = {
	nargs = '?',
	complete = autoload_complete,
	desc = 'Capture tmux pane',
}
user_command('Tcapture', autoload_user_command, opts)
user_command('Ttermcapture', autoload_user_command, opts)

user_command('Tfileyank', autoload_user_command, {
	desc = 'Yank buffer path to new tmux buffer',
})
