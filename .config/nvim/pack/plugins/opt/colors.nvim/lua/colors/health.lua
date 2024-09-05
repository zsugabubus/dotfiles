local health = vim.health

local M = {}

function M.check()
	health.start('Configuration')
	health.validate_path('vim.g.colors', function()
		return Table({
			library_path = String / Nil,
			max_highlights_per_line = Number / Nil,
			max_lines_to_highlight = Number / Nil,
			debug = Boolean / Nil,
			auto_attach = Boolean / Function / Nil,
		}) / Nil
	end)

	health.start('Runtime')
	local ok, err = pcall(require('colors').load_library)
	if ok then
		health.ok('Library loadable')
	else
		health.error(
			string.format('Library failed to load: %s', err),
			'Use |:ColorsInstall| to build and install library'
		)
	end

	health.start('Build')
	health.check_executable('cargo')
end

return M
