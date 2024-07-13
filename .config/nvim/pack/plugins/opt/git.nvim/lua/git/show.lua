local Repository = require('git.repository')
local buffer = require('git.buffer')
local revision = require('git.revision')
local utils = require('git.utils')

local function handle_user_command(opts)
	local object = opts.args
	if object == '' then
		object = '@'
	end
	vim.cmd.edit(vim.fn.fnameescape('git://' .. object))
end

local function handle_complete(prefix)
	local repo = Repository.await(Repository.from_current_buf())
	if not repo.git_dir then
		return
	end

	local rev, path, filter = string.match(prefix, '^([^:]+):(.-/?)([^/]*)$')
	if path then
		-- Complete tree paths.
		local output = utils.system(utils.make_args(repo, {
			'ls-tree',
			'-z',
			'--full-tree',
			string.format('%s:%s', rev, path),
		}))

		local result = {}

		for object_type, object_path in
			string.gmatch(output, '[^ ]* ([^ ]*)[^\t]*\t(%Z*)%z')
		do
			if string.sub(object_path, 1, #filter) == filter then
				local indicator = object_type == 'tree' and '/' or ''
				table.insert(
					result,
					string.format('%s:%s%s%s', rev, path, object_path, indicator)
				)
			end
		end

		return result
	else
		-- Complete symbolic reference.
		local patterns = {}
		for i, format in ipairs({
			'^refs/remotes/(%s.*)/HEAD$',
			'^refs/remotes/(%s.*)',
			'^refs/heads/(%s.*)',
			'^refs/tags/(%s.*)',
			'^refs/(%s.*)',
			'^(%s.*)',
		}) do
			patterns[i] = string.format(format, vim.pesc(prefix))
		end

		local output = vim.fn.systemlist(utils.make_args(repo, {
			'show-ref',
			'--dereference',
		}))

		local result = {}

		for _, x in ipairs(output) do
			local refname = string.match(x, '^[^ ]* (.*)')
			for _, pattern in ipairs(patterns) do
				local m = string.match(refname, pattern)
				if m then
					table.insert(result, m)
					-- Show the shortest match only.
					break
				end
			end
		end

		for name in vim.fs.dir(repo.git_dir) do
			if
				string.sub(name, 1, #prefix) == prefix
				and string.sub(name, -4) == 'HEAD'
			then
				table.insert(result, name)
			end
		end

		return result
	end
end

local function handle_read_autocmd(opts)
	local buf = opts.buf
	local rev = buffer.buf_get_rev(buf)

	buffer.buf_init(buf)
	local repo = Repository.from_current_buf()

	local lines = vim.fn.systemlist(utils.make_args(repo, {
		'show',
		'--compact-summary',
		'--stat=999,999,999',
		'--patch',
		'--format=format:commit %H%d%nparent %P%ntree %T%nAuthor: %aN <%aE>%nDate:   %aD%nCommit: %cN <%cE>%n%n    %s%n%-b%n',
		rev,
		-- XXX: `git show X~` shows "X is a tree, not a commit" error message
		-- multiple times without '--'.
		'--',
	}))

	local bo = vim.bo[buf]

	bo.modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
	bo.modifiable = false

	if vim.v.shell_error == 0 then
		local object_type = vim.fn.system(utils.make_args(repo, {
			'cat-file',
			'-t',
			'--',
			rev,
		}))
		if object_type == 'blob\n' then
			local _, path = revision.split_path(rev)
			local filetype, on_detect = vim.filetype.match({
				buf = buf,
				filename = path,
			})
			bo.filetype = filetype or ''
			if on_detect then
				on_detect(buf)
			end
		else
			bo.filetype = 'git'
		end
	else
		bo.filetype = 'giterror'
	end
end

return {
	handle_user_command = handle_user_command,
	handle_complete = handle_complete,
	handle_read_autocmd = handle_read_autocmd,
}
