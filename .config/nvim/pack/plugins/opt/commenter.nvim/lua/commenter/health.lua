local health = vim.health

local M = {}

function M.check()
	health.start('Configuration')
	health.validate_path('vim.g.commenter', function()
		return Table({
			get_commentstring = Function / Nil,
		}) / Nil
	end)
end

return M
