local health = vim.health

local M = {}

function M.check()
	health.start('Environment')
	health.info(string.format('`$TMUX`=`%s`', vim.inspect(vim.env.TMUX)))

	health.start('External tools')
	health.check_executable('tmux')
end

return M
