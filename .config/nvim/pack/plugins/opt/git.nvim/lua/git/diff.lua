local Repository = require('git.repository')
local utils = require('git.utils')

local function handle_user_command(opts)
	local rev = opts.args
	if rev == '' then
		rev = ':0'
	end

	local repo = Repository.await(Repository.from_current_buf())
	utils.ensure_work_tree(repo)

	local path = vim.fn.expand('%:p'):sub(#repo.work_tree + 2)
	local name = ('git://%s:%s'):format(rev, path)
	vim.cmd(
		('diffthis | leftabove vsplit %s | diffthis | wincmd p'):format(
			vim.fn.fnameescape(name)
		)
	)
end

local function handle_complete(...)
	return require('git.show').handle_complete(...)
end

return {
	handle_user_command = handle_user_command,
	handle_complete = handle_complete,
}
