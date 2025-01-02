local group = vim.api.nvim_create_augroup('explorer.http', {})

vim.api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'http://*,https://*',
	nested = true,
	callback = function(opts)
		vim.bo.buftype = 'nofile'
		vim.bo.swapfile = false

		local cmdline =
			{ 'curl', '--silent', '--location', '--globoff', opts.match }

		local contents = vim.fn.systemlist(cmdline)

		vim.api.nvim_buf_set_lines(0, 0, -1, true, contents)

		local filetype, on_detect = vim.filetype.match({ contents = contents })

		if not filetype then
			local filename = opts.match:match('//([^?#]*)'):match('/([^/]+)$') or ''
			filetype, on_detect = vim.filetype.match({ buf = 0, filename = filename })
		end

		vim.bo.filetype = filetype or ''

		if on_detect then
			on_detect(0)
		end
	end,
})
