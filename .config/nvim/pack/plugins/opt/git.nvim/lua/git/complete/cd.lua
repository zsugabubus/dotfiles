local utils = require('git.utils')
local Repository = require('git.repository')

return function(prefix)
	local repo = Repository.from_current_buf()
	if not utils.ensure_work_tree(repo) then
		return
	end

	local dir = repo.work_tree .. '/'

	local t = {}
	for _, path in
		ipairs(vim.fn.glob(utils.gesc(dir .. prefix) .. '*', false, true))
	do
		if vim.fn.isdirectory(path) ~= 0 then
			table.insert(t, string.sub(path, #dir + 1) .. '/')
		end
	end
	return t
end
