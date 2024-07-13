local Repository = require('git.repository')
local Revision = require('git.revision')
local buffer = require('git.buffer')
local cli = require('git.cli')
local utils = require('git.utils')

local api = vim.api
local fn = vim.fn

local ns = api.nvim_create_namespace('git/blame')

local function win_set_cursor_row(win, row)
	local buf = api.nvim_win_get_buf(win)
	local col = api.nvim_win_get_cursor(win)[2]
	api.nvim_win_set_cursor(
		win,
		{ math.min(api.nvim_buf_line_count(buf), row), col }
	)
end

local function user_command()
	local source_buf = api.nvim_get_current_buf()
	local source_win = api.nvim_get_current_win()
	local source_file = fn.expand('%:p')

	local rev = buffer.buf_get_rev(source_buf)
	local path
	if rev then
		rev, path = Revision.split_path(rev)
	else
		rev, path = '-', source_file
	end

	vim.cmd('topleft vsplit')

	local buf = fn.bufnr(string.format('git-blame://%s:%s', rev, path), true)
	vim.bo[buf].buflisted = true
	vim.b[buf].git_related_win = source_win
	vim.cmd.buffer(buf)
end

local function autocmd(opts)
	local buf = opts.buf
	local group = api.nvim_create_augroup('git/blame:' .. buf, {})

	vim.b[buf].git_use_preview = true
	vim.bo[buf].bufhidden = 'wipe'
	buffer.buf_init(buf)

	local repo = Repository.from_current_buf()
	local rev, path = Revision.split_path(buffer.buf_get_rev(0))

	local commit
	local start_row, end_row

	local max_row = 0
	local commits = {}
	local row2commit = {}

	local content_win = vim.b[buf].git_related_win
	local win = fn.bufwinid(buf)
	-- It seems like buffer is always associated with a window even if it is
	-- hidden and `bufload`ed in the background. It's surely documented
	-- somewhere.
	assert(win ~= -1)

	do
		local wo = vim.wo[win]
		wo.fillchars = 'eob: '
		wo.list = false
		wo.number = false
		wo.relativenumber = false
		wo.scrollbind = false
		wo.spell = false
		wo.statuscolumn = ''
		wo.winfixwidth = true
	end

	local function done()
		if not api.nvim_buf_is_valid(buf) then
			return
		end

		local commit2str = {}

		for _, commit in pairs(commits) do
			commit2str[commit] = string.format(
				'%s %s %s',
				string.sub(commit.hash, 1, 7),
				os.date('%Y-%m-%d', commit['author-time']),
				commit['author']
			)
		end

		local lines = {}

		for i = 1, max_row do
			lines[i] = commit2str[row2commit[i]]
		end

		vim.bo[buf].modifiable = true
		api.nvim_buf_set_lines(buf, 0, -1, true, lines)
		vim.bo[buf].modifiable = false

		if not api.nvim_win_is_valid(win) then
			return
		end

		local max_width = 0

		for _, s in pairs(commit2str) do
			local width = fn.strdisplaywidth(s)
			max_width = math.max(max_width, width)
		end

		api.nvim_win_set_width(win, max_width)

		if not content_win then
			return
		end

		local content_view = api.nvim_win_call(content_win, function()
			return fn.winsaveview()
		end)

		api.nvim_win_call(win, function()
			fn.winrestview({
				lnum = content_view.lnum,
				topfill = content_view.topfill,
				topline = content_view.topline,
			})
		end)

		vim.wo[content_win].scrollbind = true
		vim.wo[win].scrollbind = true

		local content_buf = api.nvim_win_get_buf(content_win)

		local current_commit
		local function set_current_commit(commit, auto_preview)
			if commit == current_commit then
				return
			end
			current_commit = commit

			api.nvim_buf_clear_namespace(content_buf, ns, 0, -1)
			api.nvim_buf_clear_namespace(buf, ns, 0, -1)

			if not current_commit then
				return
			end

			for _, line in ipairs(current_commit.lines) do
				api.nvim_buf_add_highlight(content_buf, ns, 'Visual', line - 1, 0, -1)
				api.nvim_buf_add_highlight(buf, ns, 'Visual', line - 1, 0, -1)
			end

			if auto_preview and utils.get_previewwindow() then
				buffer.goto_revision(current_commit.hash)
			end
		end

		local function set_current_row(row, auto_preview)
			set_current_commit(row2commit[row], auto_preview)
		end

		api.nvim_create_autocmd('CursorMoved', {
			group = group,
			buffer = content_buf,
			callback = function()
				local row = api.nvim_win_get_cursor(0)[1]
				win_set_cursor_row(win, row)
				set_current_row(row, false)
			end,
		})

		api.nvim_create_autocmd('CursorMoved', {
			group = group,
			buffer = buf,
			nested = true,
			callback = function()
				local row = api.nvim_win_get_cursor(0)[1]
				win_set_cursor_row(content_win, row)
				set_current_row(row, true)
			end,
		})

		api.nvim_create_autocmd('BufWipeout', {
			group = group,
			buffer = buf,
			callback = function()
				set_current_commit(nil, false)
				api.nvim_del_augroup_by_id(group)

				if api.nvim_win_is_valid(content_win) then
					vim.wo[content_win].scrollbind = false
				end
			end,
		})

		api.nvim_create_autocmd({ 'BufHidden', 'BufWipeout' }, {
			group = group,
			buffer = content_buf,
			callback = function()
				api.nvim_del_augroup_by_id(group)
			end,
		})
	end

	local FAKE_WORKTREE_REV = '--incremental'

	cli.buf_run(buf, repo, {
		stdout_mode = 'line',
		args = {
			'blame',
			'--incremental',
			rev == '-' and FAKE_WORKTREE_REV or rev,
			'--',
			path,
		},
		on_stderr = function(data)
			vim.schedule(function()
				utils.log_error(data)
			end)
		end,
		on_stdout = function(data)
			if not data then
				return vim.schedule(done)
			end
			if data == '' then
				return
			end

			local k, v = string.match(data, '^([^ ]+) ?(.*)')
			if #k == 40 then
				local hash, sourceline, resultline, num_lines =
					k, string.match(v, '^(%d+) (%d+) (%d+)')
				start_row = resultline
				end_row = resultline + num_lines - 1
				max_row = math.max(max_row, end_row)
				commit = commits[hash]
				if not commit then
					commit = {
						hash = hash,
						lines = {},
					}
					commits[hash] = commit
				end
			elseif k == 'filename' then
				for i = start_row, end_row do
					row2commit[i] = commit
					table.insert(commit.lines, i)
				end
			else
				commit[k] = v
			end
		end,
	})

	api.nvim_buf_set_keymap(buf, 'n', '<Plug>(git-blame-goto-revision)', '', {
		callback = function()
			local row = api.nvim_win_get_cursor(0)[1]
			local commit = row2commit[row]

			if not commit then
				utils.log_error('No revision under cursor')
				return
			end

			buffer.goto_revision(commit.hash)
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

return {
	user_command = user_command,
	autocmd = autocmd,
}
