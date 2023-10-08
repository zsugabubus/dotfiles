local M = {}

local function check_executable(x)
	if vim.fn.executable(x) == 1 then
		vim.health.report_ok(('%s executable found'):format(x))
	else
		vim.health.report_error(
			('%s not found in search path or not executable'):format(x)
		)
	end
end

function M.check()
	vim.health.report_start('git')
	check_executable('git')
end

return M
