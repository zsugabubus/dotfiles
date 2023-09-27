local Repository = require('git.repository')
local buffer = require('git.buffer')
local cli = require('git.cli')
local utils = require('git.utils')

return function(prefix)
	if prefix == '%' then
		return { buffer.current_rev() }
	end

	local repo = Repository.from_current_buf()
	if not repo.git_dir then
		return
	end

	local rev, path, filter = string.match(prefix, '^([^:]+):(.-/?)([^/]*)$')
	if path then
		-- Complete tree paths.
		local output = utils.system(cli.make_args(repo, {
			'ls-tree',
			'-z',
			'--full-tree',
			string.format('%s:%s', rev, path),
		}, true))

		local result = {}

		for x in
			vim.gsplit(output, '\0', {
				trimempty = true,
			})
		do
			local object_type, object_path =
				string.match(x, '^[^ ]* ([^ ]+)[^\t]*\t(.*)')
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
			'^(%s.*)',
			'^refs/(%s.*)',
			'^refs/tags/(%s.*)',
			'^refs/heads/(%s.*)',
			'^refs/remotes/(%s.*)',
			'^refs/remotes/(%s.*)/HEAD$',
		}) do
			patterns[i] = string.format(format, vim.pesc(prefix))
		end

		local output = vim.fn.systemlist(cli.make_args(repo, {
			'show-ref',
			'--dereference',
		}, true))

		local result = {}

		for name in vim.fs.dir(repo.git_dir) do
			if
				string.sub(name, 1, #prefix) == prefix
				and string.sub(name, -4) == 'HEAD'
			then
				table.insert(result, name)
			end
		end

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

		return result
	end
end
