local data = require('vnicode.data')

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
	vim.health.report_start('vnicode')
	vim.health.report_info(
		('data_dir: %s'):format(vim.inspect(data.get_data_dir()))
	)
	local x = data.get_installed_ucds()
	if #x == 0 then
		vim.health.report_warn('No installed data files found', ':VnicodeInstall')
	else
		vim.health.report_info(('Installed: %s'):format(vim.inspect(x)))
	end
	check_executable('curl')
	check_executable('xz')
end

return M
