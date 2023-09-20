local Repository = require('git.repository')
local utils = require('git.utils')

return function(opts)
	local rev = opts.args
	if rev == '' then
		rev = ':0'
	end

	local repo = Repository.await(Repository.from_current_buf())
	utils.ensure_work_tree(repo)

	vim.cmd.diffthis()
	vim.cmd.vsplit(
		string.format(
			'git://%s:%s',
			rev,
			string.sub(vim.fn.expand('%:p'), #repo.work_tree + 2)
		)
	)

	vim.cmd.diffthis()

	vim.cmd.wincmd('p')
	vim.cmd.wincmd('L')
end
