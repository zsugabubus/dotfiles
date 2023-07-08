local Repository = require('git.repository')
local utils = require('git.utils')

return function(cmd, opts)
	local repo = Repository.from_current_buf()
	if utils.ensure_work_tree(repo) then
		vim.cmd[cmd](repo.work_tree .. '/' .. opts.args)
	end
end
