local M = {}

function M.check()
	vim.health.start('External tools')
	vim.health.check_executable('git')
end

return M
