return function(prefix)
	if prefix == '%' then
		return { require('git.buffer').current_rev() }
	end

	local Repository = require('git.repository')
	local repo = Repository.from_current_buf()
	if not repo.git_dir then
		return
	end

	local Cli = require('git.cli')

	local rev, path, filter = string.match(prefix, '^([^:]+):(.-/?)([^/]*)$')
	if path then
		local Utils = require('git.utils')

		-- Complete tree paths.
		local output = Utils.system(Cli.make_args(repo, {
			'ls-tree',
			'-z',
			'--full-tree',
			string.format('%s:%s', rev, path),
		}, true))

		local t = {}

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
					t,
					string.format('%s:%s%s%s', rev, path, object_path, indicator)
				)
			end
		end

		return t
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

		local output_lines = vim.fn.systemlist(Cli.make_args(repo, {
			'show-ref',
			'--dereference',
		}, true))

		local t = {}

		for name in vim.fs.dir(repo.git_dir) do
			if
				string.sub(name, 1, #prefix) == prefix
				and string.sub(name, -4) == 'HEAD'
			then
				table.insert(t, name)
			end
		end

		for _, x in ipairs(output_lines) do
			local refname = string.match(x, '^[^ ]* (.*)')
			for _, pattern in ipairs(patterns) do
				local m = string.match(refname, pattern)
				if m then
					table.insert(t, m)
					-- Show the shortest match only.
					break
				end
			end
		end

		return t
	end
end
