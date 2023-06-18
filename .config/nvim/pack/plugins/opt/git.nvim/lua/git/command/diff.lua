return function(opts)
	local Utils = require('git.utils')
	local Repository = require('git.repository')

	local rev = opts.args
	if rev == '' then
		rev = ':0'
	end

	local repo = Repository.from_current_buf()
	if not Utils.ensure_work_tree(repo) then
		return
	end

	vim.cmd.diffthis()
	vim.cmd.vsplit(
		'git://'
			.. rev
			.. ':'
			.. string.sub(vim.fn.expand('%:p'), #repo.work_tree + 2)
	)

	vim.cmd.diffthis()

	vim.cmd.wincmd('p')
	vim.cmd.wincmd('L')
end
