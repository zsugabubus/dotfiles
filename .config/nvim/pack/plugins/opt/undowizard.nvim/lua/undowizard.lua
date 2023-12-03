local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

local M = {}

local MIN = 60
local HOUR = 60 * MIN
local DAY = 24 * HOUR

local wundo_file
local wundoed_max_number = 0
local wundoed_buf
local rundo_buf

local function buf_get_win(buf)
	return assert(api.nvim_list_wins()[fn.bufwinnr(buf)])
end

local function buf_get_undotree(buf)
	local result
	api.nvim_buf_call(buf, function()
		result = fn.undotree()
	end)
	return result
end

local function buf_undo(buf, undo_number)
	api.nvim_buf_call(buf, function()
		cmd(string.format('undo %d', undo_number))
	end)
end

local function human_elapsed_time(x)
	if x <= 1 then
		return 'just now'
	elseif x < 2 * MIN then
		return string.format('%d seconds ago', math.floor(x))
	elseif x < 2 * HOUR then
		return string.format('%d minutes ago', math.floor(x / MIN))
	elseif x < 2 * DAY then
		return string.format('%d hours ago', math.floor(x / HOUR))
	else
		return string.format('%d days ago', math.floor(x / DAY))
	end
end

local function human_time(time, now)
	local elapsed = now - time
	local today = fn.strftime('%F', time) == fn.strftime('%F', now)
	local within_one_week = elapsed < 7 * DAY
	local this_year = fn.strftime('%Y', time) == fn.strftime('%Y', now)

	local fmt
	if today then
		fmt = '%T'
	elseif within_one_week then
		fmt = '%a %T'
	elseif this_year then
		fmt = '%a %b %d %T'
	else
		fmt = '%a %b %d %Y %T'
	end

	return string.format(
		'%s (%s)',
		human_elapsed_time(elapsed),
		fn.strftime(fmt, time)
	)
end

local function get_target_buf(buf)
	local name = api.nvim_buf_get_name(buf)
	return assert(tonumber(string.match(name, '://(%d+)$')))
end

local function undotree_to_repo(undotree)
	local repo = {
		commits = {},
		commit_by_number = {},
		head = nil,
		saved = nil,
		max_level = 0,
	}

	local function process_branch(entries, parent, level)
		repo.max_level = math.max(repo.max_level, level)
		for _, entry in ipairs(entries) do
			local commit = {
				number = entry.seq,
				saved = entry.save ~= nil,
				time = entry.time,
				parent = parent,
				level = level,
			}
			table.insert(repo.commits, commit)
			repo.commit_by_number[commit.number] = commit

			if undotree.seq_cur == commit.number then
				repo.head = commit
			end

			if undotree.save_last == entry.save then
				repo.saved = commit
			end

			if entry.alt then
				process_branch(entry.alt, parent, level + 1)
			end

			parent = commit
		end
	end

	local root = {
		number = 0,
		time = 0,
		level = 0,
	}
	repo.head = root
	repo.saved = root
	table.insert(repo.commits, root)
	process_branch(undotree.entries, root, 0)

	return repo
end

local function load_undo(buf, undo_number)
	if undo_number > wundoed_max_number or wundoed_buf ~= buf then
		wundoed_buf = buf

		if not wundo_file then
			wundo_file = fn.tempname()
		end

		if not rundo_buf then
			rundo_buf = api.nvim_create_buf(false, true)
			local bo = vim.bo[rundo_buf]
			bo.undolevels = -1
		end

		api.nvim_buf_call(buf, function()
			cmd.wundo(wundo_file)
		end)

		local contents = api.nvim_buf_get_lines(buf, 0, -1, true)
		api.nvim_buf_set_lines(rundo_buf, 0, -1, true, contents)

		api.nvim_buf_call(rundo_buf, function()
			cmd(string.format('silent rundo %s', wundo_file))
			wundoed_max_number = fn.undotree().seq_last
		end)
	end
	api.nvim_buf_call(rundo_buf, function()
		cmd(string.format('silent undo %d', undo_number))
	end)
	return rundo_buf
end

local function buf_get_lines_at_undo(buf, undo_number, ...)
	return api.nvim_buf_get_lines(load_undo(buf, undo_number), ...)
end

local function make_buf_undo_blob_lookup(buf)
	return setmetatable({}, {
		__index = function(self, number)
			local lines = buf_get_lines_at_undo(buf, number, 0, -1, false)
			-- Add trailing CR.
			table.insert(lines, '')
			local contents = table.concat(lines, '\n')
			self[number] = contents
			return contents
		end,
	})
end

local function populate_commit_diffs(repo, buf, opts)
	opts = opts or {}

	local lines = make_buf_undo_blob_lookup(buf)

	for _, commit in ipairs(repo.commits) do
		if commit.parent then
			commit.diff_patch =
				vim.diff(lines[commit.parent.number], lines[commit.number], {
					ctxlen = opts.context,
				})
			local hunks =
				vim.diff(lines[commit.parent.number], lines[commit.number], {
					result_type = 'indices',
				})
			if #hunks > 0 then
				local first_hunk = hunks[1]
				local last_hunk = hunks[#hunks]
				if last_hunk[2] > 0 then
					commit.diff_before_range =
						{ first_hunk[1], last_hunk[1] + last_hunk[2] - 1 }
				end
				if last_hunk[4] > 0 then
					commit.diff_range = { first_hunk[3], last_hunk[3] + last_hunk[4] - 1 }
				end
			end
		end
	end
end

local function gsplit_lines(s)
	return string.gmatch(s, '([^\n]+)\n?')
end

local function buf_set_folds(buf, ranges)
	api.nvim_buf_call(buf, function()
		cmd.normal({ args = { 'zE' }, bang = true })
		for _, range in ipairs(ranges) do
			cmd.fold({ range = range })
		end
	end)
end

local function get_current_undo_number()
	for row = api.nvim_win_get_cursor(0)[1], 2, -1 do
		local undo_number =
			string.match(api.nvim_buf_get_lines(0, row - 1, row, true)[1], '^ *(%d+)')
		if undo_number then
			return tonumber(undo_number)
		end
	end
end

local function make_undo_bufname(buf, undo_number)
	return string.format('undo://%d/%d', buf, undo_number)
end

local function action_preview_undo_number(repo, before_change)
	local undo_number = assert(get_current_undo_number())
	local commit = assert(repo.commit_by_number[undo_number])
	-- Fall back to the other range to stay close to context.
	local diff_range = commit.diff_range or commit.diff_before_range

	if before_change then
		undo_number = commit.parent.number
		diff_range = commit.diff_before_range or commit.diff_range
	end

	local target_buf = get_target_buf(0)
	local name = make_undo_bufname(target_buf, undo_number)
	cmd.pedit(name)

	if not diff_range then
		return
	end

	local preview_buf = fn.bufnr(name)
	api.nvim_buf_call(preview_buf, function()
		cmd.normal({
			args = { string.format('%dGV%dG\x1b', diff_range[2], diff_range[1]) },
			bang = true,
		})
	end)
end

local function action_undo_to()
	local undo_number = assert(get_current_undo_number())
	local target_buf = get_target_buf(0)
	buf_undo(target_buf, undo_number)
end

local function action_yank_undo_patch(repo, before_change)
	local undo_number = assert(get_current_undo_number())
	local commit = assert(repo.commit_by_number[undo_number])
	local diff_range = commit.diff_range

	if before_change then
		undo_number = commit.parent.number
		diff_range = commit.diff_before_range
	end

	if not diff_range then
		api.nvim_echo({ { 'Nothing to yank', 'Normal' } }, false, {})
		return
	end

	local target_buf = get_target_buf(0)
	local name = make_undo_bufname(target_buf, undo_number)
	local buf = fn.bufnr(name, true)
	fn.bufload(buf)

	api.nvim_buf_call(buf, function()
		cmd.normal({
			args = { string.format('%dGV%dGy', diff_range[2], diff_range[1]) },
		})
	end)
end

local function get_commit_symbol(commit, repo)
	local current = repo.head == commit
	local fmt = current and '(%s)' or ' %s '
	local s = '*'
	if repo.saved == commit then
		s = 'S'
	elseif commit.saved then
		s = 's'
	end
	return string.format(fmt, s)
end

local function get_commit_when(commit, now)
	if commit.time == 0 then
		return 'Original'
	end
	return human_time(commit.time, now)
end

local function update(buf)
	local target_buf = get_target_buf(buf)

	local now = fn.localtime()
	local undotree = buf_get_undotree(target_buf)

	local repo = undotree_to_repo(undotree)
	populate_commit_diffs(repo, target_buf, {
		context = 1,
	})

	table.sort(repo.commits, function(a, b)
		return a.time > b.time
	end)

	local lines = {}
	local folds = {}
	local cursor = 1
	table.insert(
		lines,
		string.format('number       %swhen', string.rep(' ', repo.max_level))
	)

	for _, commit in ipairs(repo.commits) do
		local current = repo.head == commit
		if current then
			cursor = #lines + 1
		end
		table.insert(
			lines,
			string.format(
				'%6s  %s%s%s  %s',
				commit.number,
				string.rep(' ', commit.level),
				get_commit_symbol(commit, repo),
				string.rep(' ', repo.max_level - commit.level),
				get_commit_when(commit, now)
			)
		)
		if commit.diff_patch then
			local fold_start = #lines
			for line in gsplit_lines(commit.diff_patch) do
				table.insert(lines, line)
			end
			if fold_start < #lines then
				table.insert(folds, { fold_start, #lines })
			end
		end
	end

	local bo = vim.bo[buf]
	bo.modifiable = true
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	bo.modifiable = false

	buf_set_folds(buf, folds)

	local win = buf_get_win(buf)
	api.nvim_win_set_cursor(win, { cursor, 0 })
	api.nvim_buf_call(buf, function()
		vim.cmd.normal({ args = { 'zz' }, bang = true })
	end)

	api.nvim_buf_set_keymap(buf, 'n', '+', '', {
		nowait = true,
		callback = function()
			action_preview_undo_number(repo)
		end,
	})

	api.nvim_buf_set_keymap(buf, 'n', '-', '', {
		nowait = true,
		callback = function()
			action_preview_undo_number(repo, true)
		end,
	})

	api.nvim_buf_set_keymap(buf, 'n', 'gf', '-', {
		nowait = true,
	})

	api.nvim_buf_set_keymap(buf, 'n', 'y+', '', {
		nowait = true,
		callback = function()
			action_yank_undo_patch(repo)
		end,
	})

	api.nvim_buf_set_keymap(buf, 'n', 'y-', '', {
		nowait = true,
		callback = function()
			action_yank_undo_patch(repo, true)
		end,
	})

	api.nvim_buf_set_keymap(buf, 'n', 'u', '', {
		nowait = true,
		callback = function()
			action_undo_to()
		end,
	})

	api.nvim_buf_set_keymap(buf, 'n', '<CR>', 'u', {
		nowait = true,
	})

	api.nvim_buf_set_keymap(buf, 'n', '<Space>', 'za', {
		nowait = true,
	})
end

function _G.undowizard_foldtext()
	local row = vim.v.foldstart
	return api.nvim_buf_get_lines(0, row - 1, row, true)[1]
end

local function win_set_local_options(win, t)
	local opts = { scope = 'local', win = win }
	for name, value in pairs(t) do
		api.nvim_set_option_value(name, value, opts)
	end
end

function M.read_undo(opts)
	local target_buf, undo_number = string.match(opts.match, '://(%d+)/(%d+)')
	target_buf = assert(tonumber(target_buf))
	undo_number = assert(tonumber(undo_number))

	local target_bo = vim.bo[target_buf]

	local bo = vim.bo
	bo.buftype = 'nofile'
	bo.filetype = target_bo.filetype
	bo.swapfile = false
	bo.undolevels = -1

	local lines = buf_get_lines_at_undo(target_buf, undo_number, 0, -1, true)

	bo.modifiable = true
	api.nvim_buf_set_lines(0, 0, -1, false, lines)
	bo.modifiable = false
end

function M.read_undotree(opts)
	local bo = vim.bo
	bo.bufhidden = 'wipe'
	bo.buflisted = false
	bo.buftype = 'nofile'
	bo.filetype = 'diff'
	bo.swapfile = false
	bo.undolevels = -1

	win_set_local_options(win, {
		fillchars = 'fold: ',
		foldtext = 'v:lua.undowizard_foldtext()',
		list = false,
		number = false,
		relativenumber = false,
		winhighlight = 'Folded:Normal',
	})

	local buf = api.nvim_get_current_buf()
	local target_buf = get_target_buf(buf)
	local group =
		api.nvim_create_augroup(string.format('undotree/%d', target_buf), {})

	api.nvim_create_autocmd('TextChanged', {
		group = group,
		buffer = target_buf,
		callback = function()
			if not api.nvim_buf_is_valid(buf) then
				return true
			end
			update(buf)
		end,
	})

	update(buf)
end

return M
