local Repository = require('git.repository')
local utils = require('git.utils')

return function(prefix)
	local repo = Repository.from_current_buf()
	utils.ensure_work_tree(repo)

	local dir = repo.work_tree .. '/'
	local result = {}

	for _, path in
		ipairs(vim.fn.glob(utils.gesc(dir .. prefix) .. '*', false, true))
	do
		local indicator = vim.fn.isdirectory(path) ~= 0 and '/' or ''
		local filename = string.sub(path, #dir + 1)
		table.insert(result, filename .. indicator)
	end

	return result
end
