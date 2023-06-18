return function(cmd, opts)
	local Utils = require('git.utils')
	local Repository = require('git.repository')

	local repo = Repository.from_current_buf()

	if Utils.ensure_work_tree(repo) then
		vim.cmd[cmd](repo.work_tree .. '/' .. opts.args)
	end
end
