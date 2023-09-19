local keymap = vim.api.nvim_set_keymap
local user_command = vim.api.nvim_create_user_command

local EMPTY = {}

local function toggle()
	require('cword').toggle()
end

local function enable()
	require('cword').toggle(true)
end

local function disable()
	require('cword').toggle(false)
end

keymap('', '<Plug>(cword-toggle)', '', { callback = toggle })
keymap('', '<Plug>(cword-enable)', '', { callback = enable })
keymap('', '<Plug>(cword-disable)', '', { callback = disable })

user_command('Cword', toggle, EMPTY)
user_command('CwordEnable', enable, EMPTY)
user_command('CwordDisable', disable, EMPTY)
