local Repository = require('git.repository')
local utils = require('git.utils')

return function(cmd, opts)
	local repo = Repository.await(Repository.from_current_buf())
	utils.ensure_work_tree(repo)

	local path = string.format('%s/%s', repo.work_tree, opts.args)
	vim.cmd[cmd](vim.fn.fnameescape(path))
end
