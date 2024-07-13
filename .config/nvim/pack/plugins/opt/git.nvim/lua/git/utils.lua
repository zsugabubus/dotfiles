local M = {}

function M.gesc(s)
	-- :h wildcards
	return string.gsub(s, '[][?*]', '\\%0')
end

function M.ensure_work_tree(repo)
	assert(repo.work_tree, 'This operation must be run in a work tree')
end

-- vim.fn.shellescape() is not available from callbacks.
local function shesc(s)
	return string.format("'%s'", string.gsub(s, "'", [['"'"']]))
end

function M.make_args(repo, args)
	local t = { 'git', '--no-optional-locks', '--literal-pathspecs' }

	if repo.dir then
		table.insert(t, '-C')
		table.insert(t, repo.dir)
	else
		table.insert(t, '--git-dir')
		table.insert(t, assert(repo.git_dir))
		if repo.work_tree then
			table.insert(t, '--work-tree')
			table.insert(t, repo.work_tree)
		end
	end

	for _, arg in ipairs(args) do
		table.insert(t, arg)
	end

	return t
end

-- vim.fn.system() is not 8-bit clean.
function M.system(args)
	local t = {
		'exec',
		'</dev/null',
		'2>/dev/null',
	}
	for _, x in ipairs(args) do
		table.insert(t, shesc(x))
	end

	local handle = io.popen(table.concat(t, ' '))
	local stdout = handle:read('*all')
	handle:close()
	return stdout
end

function M.execute(args)
	local t = {
		'exec',
		'</dev/null',
		'>/dev/null',
		'2>/dev/null',
	}
	for _, x in ipairs(args) do
		table.insert(t, shesc(x))
	end

	local success = os.execute(table.concat(t, ' ')) == 0
	return success
end

function M.get_previewwindow()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.wo[win].previewwindow then
			return win
		end
	end
end

function M.log_error(message)
	vim.api.nvim_echo({
		{ 'git.nvim: ', 'ErrorMsg' },
		{ message, 'ErrorMsg' },
	}, true, {})
end

return M
