local Repository = require('git.repository')
local utils = require('git.utils')

local function user_command(opts)
	local cmd = string.sub(opts.name, 2)

	local repo = Repository.await(Repository.from_current_buf())
	utils.ensure_work_tree(repo)

	local path = string.format('%s/%s', repo.work_tree, opts.args)
	vim.cmd[cmd](vim.fn.fnameescape(path))
end

local function complete(prefix)
	return vim.tbl_filter(function(path)
		return string.sub(path, -1) == '/'
	end, require('git.edit').complete(prefix))
end

return {
	user_command = user_command,
	complete = complete,
}
