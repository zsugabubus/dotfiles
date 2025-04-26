local api = vim.api

local autocmd = api.nvim_create_autocmd

local group = api.nvim_create_augroup('tilde', {})

autocmd('CmdlineLeave', {
	group = group,
	callback = function(opts)
		return require('tilde')._handle_cmdline_leave(opts)
	end,
})

autocmd('CmdlineChanged', {
	group = group,
	callback = function(opts)
		return require('tilde')._handle_cmdline_changed(opts)
	end,
})
