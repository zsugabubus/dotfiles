local health = vim.health

local M = {}

function M.check()
	health.start('Configuration')
	health.validate_path('vim.g.varign', function()
		return Table({
			auto_attach = Boolean / Nil,
		}) / Nil
	end)
end

return M
