local colors_dir = vim.fn.stdpath('config') .. '/colors'

vim.api.nvim_create_autocmd('BufWritePost', {
	group = vim.api.nvim_create_augroup('reload', {}),
	pattern = { '*.vim', '*.lua' },
	nested = true,
	callback = function(opts)
		local dir = vim.fn.fnamemodify(opts.file, ':p:h')
		if dir == colors_dir then
			vim.cmd.colorscheme(vim.fn.fnamemodify(opts.file, ':t:r'))
		end
	end,
})
