local api = vim.api
local ns = api.nvim_create_namespace('git/blame')

return function(opts)
	local Buffer = require('git.buffer')
	local Cli = require('git.cli')
	local Repository = require('git.repository')
	local Utils = require('git.utils')

	local source_buf = api.nvim_get_current_buf()
	local source_win = api.nvim_get_current_win()
	local source_file = vim.fn.expand('%:p')
	local repo = Repository.from_current_buf()

	local buf = api.nvim_create_buf(true, false)
	vim.b[buf].git_use_preview = true
	Buffer.buf_init(buf)

	vim.cmd('topleft vsplit')
	vim.cmd.buffer(buf)

	local win = api.nvim_get_current_win()
	local group = api.nvim_create_augroup('git/blame:' .. buf, {})

	local bo = vim.bo[buf]
	bo.bufhidden = 'wipe'

	local wo = vim.wo[win]
	wo.fillchars = 'eob: '
	wo.list = false
	wo.number = false
	wo.relativenumber = false
	wo.spell = false
	wo.statuscolumn = ''
	wo.statusline = 'Git Blame'
	wo.winfixwidth = true

	local commit
	local start_row, end_row

	local commits = {}
	local line2commit = {}
	local max_row = 0
	local initial_cursor = api.nvim_win_get_cursor(source_win)

	local function step()
		if
			not api.nvim_buf_is_valid(buf)
			or not api.nvim_win_is_valid(win)
			or not api.nvim_win_is_valid(source_win)
		then
			return
		end

		local lines = {}
		local commit_lines = {}

		for _, commit in pairs(commits) do
			local line = (
				string.sub(commit.hash, 1, 7)
				.. ' '
				.. vim.fn.strftime('%Y-%m-%d', commit.author_time)
				.. ' '
				.. commit.author
			)
			commit_lines[commit] = line
		end

		for i = 1, max_row do
			lines[i] = commit_lines[line2commit[i]]
		end

		bo.modifiable = true
		api.nvim_buf_set_lines(buf, 0, -1, true, lines)
		bo.modifiable = false

		api.nvim_win_set_cursor(source_win, { 1, 0 })
		api.nvim_win_set_cursor(win, { 1, 0 })
		vim.wo[source_win].scrollbind = true
		vim.wo[win].scrollbind = true
		api.nvim_win_set_cursor(win, initial_cursor)

		local max_width = 0

		for _, line in pairs(commit_lines) do
			local width = vim.fn.strdisplaywidth(line)
			max_width = math.max(max_width, width)
		end

		api.nvim_win_set_width(win, max_width)
	end

	Cli.buf_run(buf, repo, {
		stdout_mode = 'line',
		args = {
			'blame',
			'--incremental',
			opts.range == 2 and string.format('-L%d,%d', opts.line1, opts.line2)
				or '-L,',
			'--',
			source_file,
		},
		on_stderr = function(data)
			vim.schedule(function()
				vim.notify(data, vim.log.levels.ERROR, {})
				api.nvim_win_close(win, true)
			end)
		end,
		on_stdout = function(data)
			if not data then
				return vim.schedule(step)
			end
			if data == '' then
				return
			end

			local k, v = string.match(data, '^([^ ]+) ?(.*)')
			if #k == 40 then
				local sourceline, resultline, num_lines =
					string.match(v, '^(%d+) (%d+) (%d+)')
				local hash = k
				start_row = resultline
				end_row = resultline + num_lines - 1
				max_row = math.max(max_row, end_row)
				commit = commits[hash]
				if not commit then
					commit = {
						hash = hash,
						lines = {},
						author = '',
					}
					commits[hash] = commit
				end
			elseif k == 'author' then
				commit.author = v
			elseif k == 'author-time' then
				commit.author_time = tonumber(v)
			elseif k == 'filename' then
				for i = start_row, end_row do
					line2commit[i] = commit
					table.insert(commit.lines, i)
				end
			end
		end,
	})

	api.nvim_create_autocmd('BufWipeout', {
		group = group,
		nested = true,
		callback = function(opts)
			if opts.buf == source_buf then
				return api.nvim_win_close(win, true)
			end

			if opts.buf == buf then
				api.nvim_buf_clear_namespace(source_buf, ns, 0, -1)
				api.nvim_buf_clear_namespace(buf, ns, 0, -1)
				api.nvim_del_augroup_by_id(group)
			end
		end,
	})

	api.nvim_create_autocmd('WinClosed', {
		group = group,
		nested = true,
		callback = function(opts)
			opts.win = tonumber(opts.match)

			if opts.win == source_win then
				vim.schedule(function()
					api.nvim_buf_delete(buf, {
						force = true,
					})
				end)
			end
		end,
	})

	local current_commit
	local function update_cursor()
		if not api.nvim_win_is_valid(source_win) then
			return
		end

		local row = api.nvim_win_get_cursor(0)[1]

		if api.nvim_win_get_buf(source_win) == source_buf then
			local cursor = api.nvim_win_get_cursor(source_win)
			api.nvim_win_set_cursor(
				source_win,
				{ math.min(api.nvim_buf_line_count(source_buf), row), cursor[2] }
			)
		end

		do
			local cursor = api.nvim_win_get_cursor(win)
			api.nvim_win_set_cursor(
				win,
				{ math.min(api.nvim_buf_line_count(buf), row), cursor[2] }
			)
		end

		local commit = line2commit[row]
		if commit == current_commit then
			return
		end
		current_commit = commit

		api.nvim_buf_clear_namespace(source_buf, ns, 0, -1)
		api.nvim_buf_clear_namespace(buf, ns, 0, -1)

		if commit then
			for _, line in ipairs(commit.lines) do
				api.nvim_buf_add_highlight(source_buf, ns, 'Visual', line - 1, 0, -1)
				api.nvim_buf_add_highlight(buf, ns, 'Visual', line - 1, 0, -1)
			end

			local current_win = api.nvim_get_current_win()
			if current_win == win and Utils.is_preview_window_open() then
				Buffer.goto_revision(current_commit.hash)
			end
		end
	end

	for _, x in ipairs({ source_buf, buf }) do
		api.nvim_create_autocmd('CursorMoved', {
			group = group,
			buffer = x,
			nested = true,
			callback = update_cursor,
		})
	end

	api.nvim_buf_set_keymap(buf, 'n', '<Plug>(git-blame-goto-revision)', '', {
		callback = function()
			if current_commit then
				return Buffer.goto_revision(current_commit.hash)
			else
				vim.notify('git: No revision under cursor', vim.log.levels.ERROR, {})
			end
		end,
	})

	api.nvim_buf_set_keymap(
		buf,
		'n',
		'<CR>',
		'<Plug>(git-blame-goto-revision)',
		{ nowait = true }
	)
	api.nvim_buf_set_keymap(
		buf,
		'n',
		'gf',
		'<Plug>(git-blame-goto-revision)',
		{ nowait = true }
	)
end
