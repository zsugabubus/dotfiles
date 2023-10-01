local M = {
	config = {
		data_dir = vim.fn.stdpath('data') .. '/vnicode/',
	},
}

function M.setup(opts)
	M.config.data_dir = opts.data_dir or M.config.data_dir
end

return M
