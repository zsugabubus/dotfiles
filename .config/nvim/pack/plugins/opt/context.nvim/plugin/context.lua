local keymap = vim.api.nvim_set_keymap
local user_command = vim.api.nvim_create_user_command

local EMPTY = {}

local function toggle()
	require('context').toggle()
end

local function enable()
	require('context').toggle(true)
end

local function disable()
	require('context').toggle(false)
end

keymap('', '<Plug>(context-toggle)', '', { callback = toggle })
keymap('', '<Plug>(context-enable)', '', { callback = enable })
keymap('', '<Plug>(context-disable)', '', { callback = disable })

user_command('Context', toggle, EMPTY)
user_command('ContextEnable', enable, EMPTY)
user_command('ContextDisable', disable, EMPTY)
