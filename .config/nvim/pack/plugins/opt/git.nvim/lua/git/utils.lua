local M = {}

function M.gesc(pattern)
	-- FIXME: May not be totally correct.
	-- :h wildcards
	return string.gsub(pattern, '[?*]', '\\%0')
end

-- vim.fn.shellescape() is not available from callbacks.
function M.shesc(s)
	return string.format("'%s'", string.gsub(s, "'", [['"'"']]))
end

function M.ensure_work_tree(repo)
	if repo.work_tree then
		return true
	end

	vim.notify(
		'git.nvim: This operation must be run in a work tree',
		vim.log.levels.ERROR,
		{}
	)
	return false
end

-- vim.fn.system() is not 8-bit clean.
function M.system(args)
	local t = {
		'exec',
		'</dev/null',
		'2>/dev/null',
	}
	for i, x in ipairs(args) do
		table.insert(t, M.shesc(x))
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
	for i, x in ipairs(args) do
		table.insert(t, M.shesc(x))
	end

	return os.execute(table.concat(t, ' ')) == 0
end

function M.is_preview_window_open()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.wo[win].previewwindow then
			return true
		end
	end
	return false
end

return M
