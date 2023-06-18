return function(prefix)
	local Utils = require('git.utils')
	local Repository = require('git.repository')

	local repo = Repository.from_current_buf()
	if not Utils.ensure_work_tree(repo) then
		return
	end

	local dir = repo.work_tree .. '/'

	local t = {}
	for _, path in
		ipairs(vim.fn.glob(Utils.gesc(dir .. prefix) .. '*', false, true))
	do
		local indicator = vim.fn.isdirectory(path) ~= 0 and '/' or ''
		table.insert(t, string.sub(path, #dir + 1) .. indicator)
	end
	return t
end
