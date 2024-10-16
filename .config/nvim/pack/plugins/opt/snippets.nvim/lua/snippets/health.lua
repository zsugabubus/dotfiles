local health = vim.health

local M = {}

function M.check()
	health.start('Configuration')
	health.validate_path('vim.g.snippets', function()
		return Table({
			get_snippets = Function / String / Nil,
		}) / Nil
	end)
end

return M
