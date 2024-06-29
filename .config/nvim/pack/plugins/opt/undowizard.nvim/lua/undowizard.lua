local api = vim.api
local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn

local MIN = 60
local HOUR = 60 * MIN
local DAY = 24 * HOUR

local wundo_file
local wundoed_max_number = 0
local wundoed_buf
local rundo_buf

function _G._undowizard_foldtext()
	local row = vim.v.foldstart
	return api.nvim_buf_get_lines(0, row - 1, row, true)[1]
end

local function gsplit_lines(s)
	return string.gmatch(s, '([^\n]+)\n?')
end

local function elapsed_time_display(x)
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

local function is_same_day(a, b)
	return os.date('%Y-%m-%d', a) == os.date('%Y-%m-%d', b)
end

local function is_same_year(a, b)
	return os.date('%Y', a) == os.date('%Y', b)
end

local function time_display(time, now)
	local elapsed = now - time

	local format
	if is_same_day(time, now) then
		format = '%H:%M:%S'
	elseif elapsed < 7 * DAY then
		format = '%a %H:%M:%S'
	elseif is_same_year(time, now) then
		format = '%a %b %d %H:%M:%S'
	else
		format = '%a %b %d %Y %H:%M:%S'
	end

	return string.format(
		'%s (%s)',
		elapsed_time_display(elapsed),
		os.date(format, time)
	)
end

local function buf_get_undotree(buf)
	local undotree
	api.nvim_buf_call(buf, function()
		undotree = fn.undotree()
	end)
	return undotree
end

local function buf_undo(buf, undo_number)
	api.nvim_buf_call(buf, function()
		cmd(string.format('undo %d', undo_number))
	end)
end

local function set_folds(ranges)
	cmd.normal({ args = { 'zE' }, bang = true })
	for _, range in ipairs(ranges) do
		cmd.fold({ range = range })
	end
end

local function buf_load_undo(buf, undo_number)
	if undo_number > wundoed_max_number or wundoed_buf ~= buf then
		wundoed_buf = buf

		if not wundo_file then
			wundo_file = fn.tempname()
		end

		if not rundo_buf then
			rundo_buf = api.nvim_create_buf(false, true)
			bo[rundo_buf].undolevels = -1
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

local function buf_get_undo_lines(buf, undo_number, ...)
	return api.nvim_buf_get_lines(buf_load_undo(buf, undo_number), ...)
end

local function make_buf_undo_lines_lookup(buf)
	return setmetatable({}, {
		__index = function(t, undo_number)
			local lines = buf_get_undo_lines(buf, undo_number, 0, -1, false)
			-- Add trailing CR.
			table.insert(lines, '')
			local contents = table.concat(lines, '\n')
			t[undo_number] = contents
			return contents
		end,
	})
end

local function make_undo_bufname(buf, undo_number)
	return string.format('undo://%d/%d', buf, undo_number)
end

local function parse_undo_bufname(name)
	local buf, undo_number = string.match(name, '^undo://(%d+)/(%d+)')
	return assert(tonumber(buf)), assert(tonumber(undo_number))
end

local function get_target_buf(buf)
	local name = api.nvim_buf_get_name(buf)
	local target_buf = string.match(name, '^undotree://(%d+)')
	return assert(tonumber(target_buf))
end

local function get_current_undo_number()
	for row = api.nvim_win_get_cursor(0)[1], 2, -1 do
		local line = api.nvim_buf_get_lines(0, row - 1, row, true)[1]
		local undo_number = string.match(line, '^ *(%d+)')
		if undo_number then
			return tonumber(undo_number)
		end
	end
end

local function win_set_local_options(win, t)
	local opts = { scope = 'local', win = win }
	for name, value in pairs(t) do
		api.nvim_set_option_value(name, value, opts)
	end
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
	repo.commit_by_number[root.number] = root

	process_branch(undotree.entries, root, 0)

	return repo
end

local function populate_commit_diffs(repo, buf, opts)
	opts = opts or {}

	local lines = make_buf_undo_lines_lookup(buf)

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

local function open_current_undo_preview(repo, before_change)
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

local function undo_to()
	local undo_number = assert(get_current_undo_number())
	local target_buf = get_target_buf(0)
	buf_undo(target_buf, undo_number)
end

local function yank_undo_patch(repo, before_change)
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
	return time_display(commit.time, now)
end

local function update(buf)
	local now = os.time()

	local target_buf = get_target_buf(buf)
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

	local bo = bo[buf]
	bo.modifiable = true
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	bo.modifiable = false

	api.nvim_buf_call(buf, function()
		set_folds(folds)
		api.nvim_win_set_cursor(0, { cursor, 0 })
		cmd.normal({ args = { 'zz' }, bang = true })
	end)

	local keymap = api.nvim_buf_set_keymap

	keymap(buf, 'n', '+', '', {
		nowait = true,
		callback = function()
			open_current_undo_preview(repo)
		end,
		desc = 'Preview additions',
	})

	keymap(buf, 'n', '-', '', {
		nowait = true,
		callback = function()
			open_current_undo_preview(repo, true)
		end,
		desc = 'Preview deletions',
	})

	keymap(buf, 'n', 'gf', '-', {
		nowait = true,
	})

	keymap(buf, 'n', 'y+', '', {
		nowait = true,
		callback = function()
			yank_undo_patch(repo)
		end,
		desc = 'Copy additions',
	})

	keymap(buf, 'n', 'y-', '', {
		nowait = true,
		callback = function()
			yank_undo_patch(repo, true)
		end,
		desc = 'Copy deletions',
	})

	keymap(buf, 'n', 'u', '', {
		nowait = true,
		callback = function()
			undo_to()
		end,
		desc = 'Undo to',
	})

	keymap(buf, 'n', '<CR>', 'u', {
		nowait = true,
	})

	keymap(buf, 'n', '<Space>', 'za', {
		nowait = true,
	})
end

local function read_undo_autocmd(opts)
	local target_buf, undo_number = parse_undo_bufname(opts.match)

	local target_bo = bo[target_buf]

	bo.buftype = 'nofile'
	bo.filetype = target_bo.filetype
	bo.swapfile = false
	bo.modeline = false
	bo.undolevels = -1

	local lines = buf_get_undo_lines(target_buf, undo_number, 0, -1, false)

	bo.modifiable = true
	api.nvim_buf_set_lines(0, 0, -1, false, lines)
	bo.modifiable = false
end

local function read_undotree_autocmd(opts)
	bo.bufhidden = 'wipe'
	bo.buflisted = false
	bo.buftype = 'nofile'
	bo.filetype = 'diff'
	bo.swapfile = false
	bo.modeline = false
	bo.undolevels = -1

	win_set_local_options(win, {
		fillchars = 'fold: ',
		foldtext = 'v:lua._undowizard_foldtext()',
		list = false,
		number = false,
		relativenumber = false,
		winhighlight = 'Folded:Normal',
	})

	local buf = api.nvim_get_current_buf()
	local target_buf = get_target_buf(buf)

	local group = api.nvim_create_augroup(string.format('undotree/%d', buf), {})

	api.nvim_create_autocmd('TextChanged', {
		group = group,
		buffer = target_buf,
		callback = function()
			if not api.nvim_buf_is_valid(buf) then
				return true
			end
			if bo[buf].readonly then
				return
			end
			update(buf)
		end,
	})

	update(buf)
end

return {
	read_undo_autocmd = read_undo_autocmd,
	read_undotree_autocmd = read_undotree_autocmd,
}
