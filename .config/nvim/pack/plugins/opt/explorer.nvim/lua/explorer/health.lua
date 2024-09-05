local health = vim.health

local M = {}

function M.check()
	health.start('External tools')
	health.check_executable('ssh')
	health.check_executable('curl')
end

return M
