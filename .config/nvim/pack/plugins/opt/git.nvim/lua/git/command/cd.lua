local utils = require('git.utils')
local Repository = require('git.repository')

return function(cmd, opts)
	local repo = Repository.from_current_buf()
	utils.ensure_work_tree(repo)
	vim.cmd[cmd](string.format('%s/%s', repo.work_tree, opts.args))
end
