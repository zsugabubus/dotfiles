local api = vim.api

local autocmd = api.nvim_create_autocmd
local keymap = api.nvim_set_keymap
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('vnicode', {})

local M = setmetatable({}, {
	__index = function(M, k)
		getmetatable(M).__index = require('vnicode.autoload')
		return M[k]
	end,
})

function M.setup(opts)
	local default_config = {
		data_dir = vim.fn.stdpath('data') .. '/vnicode/',
	}

	M.config = setmetatable(opts or {}, { __index = default_config })

	keymap('', '<Plug>(vnicode-inspect)', '', {
		callback = function()
			require('vnicode').inspect()
		end,
	})

	user_command('VnicodeInspect', function(opts)
		vim.cmd.edit(vim.fn.fnameescape('vnicode://' .. opts.args))
	end, { nargs = '*' })

	user_command('VnicodeView', function(...)
		require('vnicode').view_cmd(...)
	end, {
		nargs = '?',
		complete = "custom,v:lua.require'vnicode'.view_complete",
	})

	user_command('VnicodeInstall', function(...)
		require('vnicode').install_cmd(...)
	end, {
		nargs = '?',
		complete = "custom,v:lua.require'vnicode'.install_complete",
	})

	user_command('VnicodeUpdate', function(opts)
		require('vnicode').update_cmd(opts)
	end, {})

	autocmd('BufReadCmd', {
		group = group,
		pattern = 'vnicode://*',
		nested = true,
		callback = function(...)
			require('vnicode').read_vnicode_autocmd(...)
		end,
	})
end

return M
