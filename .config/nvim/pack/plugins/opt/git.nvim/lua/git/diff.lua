local Repository = require('git.repository')
local utils = require('git.utils')

local function user_command(opts)
	local rev = opts.args
	if rev == '' then
		rev = ':0'
	end

	local repo = Repository.await(Repository.from_current_buf())
	utils.ensure_work_tree(repo)

	local path = string.sub(vim.fn.expand('%:p'), #repo.work_tree + 2)
	local name = string.format('git://%s:%s', rev, path)
	vim.cmd(
		string.format(
			'diffthis | leftabove vsplit %s | diffthis | wincmd p',
			vim.fn.fnameescape(name)
		)
	)
end

local function complete(prefix)
	return require('git.show').complete(prefix)
end

return {
	user_command = user_command,
	complete = complete,
}
