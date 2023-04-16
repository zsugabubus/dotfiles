if vim.env.NVIM_STARTUPTIME then
	require 'trace'.startuptime(tonumber(vim.env.NVIM_STARTUPTIME) or 10)
end
require 'bytecode-loader'
require 'secure-loader'
require 'init'
