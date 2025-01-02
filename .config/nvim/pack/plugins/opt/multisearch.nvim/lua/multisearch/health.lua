local health = vim.health

local M = {}

function M.check()
	health.start('Configuration')
	health.validate_path('vim.g.multisearch', function()
		return Table({
			highlights = Array(String) / Nil,
			very_magic = Boolean / Nil,
		}) / Nil
	end)
	for _, name in ipairs((vim.g.multisearch or {}).highlights or {}) do
		if next(vim.api.nvim_get_hl(0, { name = name })) ~= nil then
			health.ok(('Highlight %s found'):format(name))
		else
			health.error(('Highlight %s not found'):format(name))
		end
	end
end

return M
