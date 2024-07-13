local Repository = require('git.repository')
local utils = require('git.utils')

local fn = vim.fn

local function handle_user_command(opts)
	local cmd = string.sub(opts.name, 2)

	local repo = Repository.await(Repository.from_current_buf())
	utils.ensure_work_tree(repo)

	local path = string.format('%s/%s', repo.work_tree, opts.args)
	vim.cmd[cmd](fn.fnameescape(path))
end

local function handle_complete(prefix)
	local repo = Repository.await(Repository.from_current_buf())
	utils.ensure_work_tree(repo)

	local dir = repo.work_tree .. '/'
	local result = {}

	for _, path in ipairs(fn.glob(utils.gesc(dir .. prefix) .. '*', false, true)) do
		local indicator = fn.isdirectory(path) ~= 0 and '/' or ''
		local filename = string.sub(path, #dir + 1)
		table.insert(result, filename .. indicator)
	end

	return result
end

return {
	handle_user_command = handle_user_command,
	handle_complete = handle_complete,
}
