local api = vim.api

local autocmd = api.nvim_create_autocmd
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('tmux', {})

local function autoload_user_command(opts)
	return require('tmux')[opts.name](opts)
end

local function autoload_complete(prefix, cmdline)
	local name = vim.fn.fullcommand(string.match(cmdline, '([^ ]*)'))
	return require('tmux')[name .. '_complete'](prefix)
end

autocmd({ 'BufReadCmd', 'BufWriteCmd' }, {
	group = group,
	pattern = { 'tmux://buffers/*', 'tmux://panes/*' },
	callback = function(opts)
		local name = opts.event
			.. '_'
			.. string.match(opts.match, '^tmux://([^/]*)')
		return require('tmux')[name](opts)
	end,
})

user_command('Tbuffers', autoload_user_command, {
	desc = 'List tmux buffers',
})
user_command('Tbuffer', autoload_user_command, {
	nargs = 1,
	complete = autoload_complete,
	desc = 'Edit tmux buffer',
})

user_command('Twrite', autoload_user_command, {
	nargs = '?',
	desc = 'Write buffer to tmux buffer',
	range = 2,
})

user_command('Tpanes', autoload_user_command, {
	desc = 'List tmux panes',
})
user_command('Tpane', autoload_user_command, {
	bang = true,
	nargs = 1,
	complete = autoload_complete,
	desc = 'View tmux pane',
})
user_command('Tlast', 'Tpane! {last}', {})

user_command('Tcd', autoload_user_command, {
	nargs = 1,
	complete = autoload_complete,
	desc = 'Cd to tmux pane',
})

user_command('Tsplitwindow', autoload_user_command, {
	-- :lcd and :tcd do not set process working directory.
	desc = 'tmux split-window',
})
