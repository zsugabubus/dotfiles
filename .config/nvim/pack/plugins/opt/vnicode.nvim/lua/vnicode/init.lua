local M = {}

function M.setup(opts)
	local default_config = {
		data_dir = vim.fn.stdpath('data') .. '/vnicode/',
	}

	M.config = setmetatable(opts or {}, { __index = default_config })

	local api = vim.api
	local keymap = api.nvim_set_keymap
	local user_command = api.nvim_create_user_command

	keymap('', '<Plug>(vnicode-unicode)', '', {
		callback = function()
			require('vnicode.commands').ga()
		end,
	})

	keymap('', '<Plug>(vnicode-utf8)', '', {
		callback = function()
			require('vnicode.commands').g8()
		end,
	})

	user_command('Vnicode', function(...)
		require('vnicode.commands').view(...)
	end, {
		nargs = '?',
		complete = function(...)
			return require('vnicode.commands').view_complete(...)
		end,
	})

	user_command('VnicodeInstall', function(...)
		require('vnicode.commands').install(...)
	end, {
		nargs = '?',
		complete = function(...)
			return require('vnicode.commands').install_complete(...)
		end,
	})

	user_command('VnicodeUpdate', function(opts)
		require('vnicode.commands').update(opts)
	end, {})
end

return M
