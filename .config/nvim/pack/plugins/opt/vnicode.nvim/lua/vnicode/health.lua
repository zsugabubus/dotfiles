local health = vim.health

local M = {}

function M.check()
	health.start('Configuration')
	health.validate_path('vim.g.vnicode', function()
		return Table({
			data_dir = String / Nil,
		}) / Nil
	end)
	local vnicode = require('vnicode')
	health.info(('`vim.g.vnicode.data_dir`: `%s`'):format(vnicode.get_data_dir()))

	health.start('Data')
	local ucds = vnicode.get_installed_ucds()
	if #ucds == 0 then
		health.warn('No UCDs found', {
			'Install defaults with |:VnicodeInstall|',
			'Install a specific one with |:VnicodeInstall| {ucd-name}',
		})
	else
		health.info(('Installed UCDs: %s'):format(table.concat(ucds, ', ')))
	end

	health.start('External tools')
	health.check_executable('curl')
	health.check_executable('xz')
end

return M
