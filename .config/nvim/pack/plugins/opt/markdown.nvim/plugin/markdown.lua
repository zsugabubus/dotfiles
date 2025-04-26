local user_command = vim.api.nvim_create_user_command

user_command('MarkdownPreviewStart', function(opts)
	local port = assert(tonumber(opts.fargs[1] or 0))
	local host = opts.fargs[2] or '127.0.0.1'
	require('markdown').start_server(host, port)
end, { nargs = '*', desc = 'Start markdown preview server' })

user_command('MarkdownPreviewStop', function()
	require('markdown').stop_server()
end, { desc = 'Stop markdown preview server' })
