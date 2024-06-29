local M = {}

local function check_executable(x)
	if vim.fn.executable(x) == 1 then
		vim.health.ok(('%s executable found'):format(x))
	else
		vim.health.error(
			('%s not found in search path or not executable'):format(x)
		)
	end
end

function M.check()
	local vnicode = require('vnicode')

	vim.health.start('vnicode')
	vim.health.info(('data_dir: %s'):format(vim.inspect(vnicode.get_data_dir())))
	local x = vnicode.get_installed_ucds()
	if #x == 0 then
		vim.health.warn('No installed data files found', ':VnicodeInstall')
	else
		vim.health.info(('Installed: %s'):format(vim.inspect(x)))
	end
	check_executable('curl')
	check_executable('xz')
end

return M
