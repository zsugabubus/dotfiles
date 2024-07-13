local Repository = require('git.repository')
local utils = require('git.utils')

local function handle_user_command(opts)
	local cmd = string.sub(opts.name, 2)

	local repo = Repository.await(Repository.from_current_buf())
	utils.ensure_work_tree(repo)

	local path = string.format('%s/%s', repo.work_tree, opts.args)
	vim.cmd[cmd](vim.fn.fnameescape(path))
end

local function handle_complete(...)
	return vim.tbl_filter(function(path)
		return string.sub(path, -1) == '/'
	end, require('git.edit').handle_complete(...))
end

return {
	handle_user_command = handle_user_command,
	handle_complete = handle_complete,
}
