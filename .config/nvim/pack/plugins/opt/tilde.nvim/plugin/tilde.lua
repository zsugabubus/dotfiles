local api = vim.api

local group = api.nvim_create_augroup('tilde', {})

api.nvim_create_autocmd('CmdlineLeave', {
	group = group,
	callback = function(opts)
		return require('tilde')._handle_cmdline_leave(opts)
	end,
})

api.nvim_create_autocmd('CmdlineChanged', {
	group = group,
	callback = function(opts)
		return require('tilde')._handle_cmdline_changed(opts)
	end,
})
