local cli = require('git.cli')
local Repository = require('git.repository')
local Revision = require('git.revision')
local utils = require('git.utils')

local api = vim.api

local M = {}

function M.buf_pipe(buf, opts)
	assert(buf ~= 0)

	local bo = vim.bo[buf]

	local last_row, last_col = 0, 0
	local ends_with_newline = false
	local first = true
	local process_success, stdout_closed

	local function step()
		vim.schedule(function()
			if not api.nvim_buf_is_valid(buf) then
				return
			end

			if ends_with_newline then
				bo.modifiable = true
				api.nvim_buf_set_lines(buf, -2, -1, false, {})
				bo.modifiable = false
			end

			for _, win in ipairs(api.nvim_list_wins()) do
				if api.nvim_win_get_buf(win) == buf then
					api.nvim_win_set_cursor(win, { 1, 0 })
				end
			end

			vim.cmd.diffupdate()

			if opts.callback then
				return opts.callback(process_success)
			end
		end)
	end

	local repo = Repository.from_buf(buf)
	return cli.buf_run(buf, repo, {
		args = opts.args,
		stdout_mode = 'stream',
		on_stderr = function(data)
			vim.schedule(function()
				if not api.nvim_buf_is_valid(buf) then
					return
				end

				bo.modifiable = true
				api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(data, '\n'))
				bo.modifiable = false
			end)
		end,
		callback = function(success)
			process_success = success
			if stdout_closed then
				return step()
			end
		end,
		on_stdout = function(data)
			if not data then
				stdout_closed = true
				if process_success ~= nil then
					return step()
				end
				return
			end

			vim.schedule(function()
				if not api.nvim_buf_is_valid(buf) then
					return
				end

				local lines = vim.split(data, '\n')

				bo.modifiable = true
				if first then
					first = false
					-- To avoid flickering clear old buffer content and add first
					-- chunk in one go.
					api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				else
					api.nvim_buf_set_text(
						buf,
						last_row,
						last_col,
						last_row,
						last_col,
						lines
					)
				end
				bo.modifiable = false

				if #lines == 1 then
					last_col = last_col + #lines[1]
				else
					last_row = last_row + #lines - 1
					last_col = #lines[#lines]
				end

				ends_with_newline = lines[#lines] == ''
			end)
		end,
	})
end

local function buf_detect_blob_filetype(buf, rev)
	local _, path = Revision.split_path(rev)
	local filetype, on_detect = vim.filetype.match({
		buf = buf,
		filename = path,
	})
	vim.bo[buf].filetype = filetype or ''
	if on_detect then
		on_detect(buf)
	end
end

local function buf_detect_object_filetype(buf, rev)
	local repo = Repository.from_buf(buf)
	return cli.buf_run(buf, repo, {
		args = {
			'cat-file',
			'-t',
			'--',
			rev,
		},
		on_stdout = function(data)
			vim.schedule(function()
				if not api.nvim_buf_is_valid(buf) then
					return
				end

				if data == 'blob\n' then
					return buf_detect_blob_filetype(buf, rev)
				else
					vim.bo[buf].filetype = 'git'
				end
			end)
		end,
	})
end

function M.buf_get_rev(buf)
	return string.match(api.nvim_buf_get_name(buf), '^git[^:]*://(.*)')
end

function M.current_rev()
	return M.buf_get_rev(0) or ''
end

local function buf_map(buf, lhs, rhs)
	if type(rhs) == 'function' then
		return api.nvim_buf_set_keymap(buf, 'n', lhs, '', {
			nowait = true,
			callback = rhs,
		})
	else
		return api.nvim_buf_set_keymap(buf, 'n', lhs, rhs, {
			nowait = true,
		})
	end
end

function M.goto_revision(rev, use_git)
	local protocol = not use_git
			and string.match(api.nvim_buf_get_name(0), '^git[^:]*://')
		or 'git://'
	local file = vim.fn.fnameescape(protocol .. rev)

	-- May block file open since it can make rev expand to nothing.
	local saved_wildignore = vim.go.wildignore
	vim.go.wildignore = ''

	local use_preview = protocol == 'git://' and vim.b.git_use_preview

	if use_preview then
		local saved_previewheight = vim.go.previewheight
		vim.go.previewheight = 82
		vim.cmd(
			string.format('topleft vertical pedit +set\\ noscrollbind %s', file)
		)
		vim.go.previewheight = saved_previewheight
	else
		vim.cmd.edit(file)
	end

	vim.go.wildignore = saved_wildignore
end

function M.goto_object()
	local cfile = vim.fn.expand('<cfile>')

	if string.match(cfile, '^%x%x%x%x+$') then
		M.goto_revision(cfile)
		return
	end

	local rev = M.current_rev()
	if rev == '' then
		vim.api.nvim_feedkeys('gf', 'xtin', false)
		return
	end

	return M.goto_revision(Revision.join(rev, cfile))
end

local function goto_parent_tree()
	local parent = Revision.parent_tree(M.current_rev())
	if not parent then
		return utils.log_error('Not a tree-ish revision')
	end
	return M.goto_revision(parent)
end

local function goto_ancestor()
	return M.goto_revision(Revision.ancestor(M.current_rev(), vim.v.count1))
end

local function goto_parent()
	return M.goto_revision(Revision.parent_commit(M.current_rev(), vim.v.count1))
end

function M.buf_init(buf)
	local bo = vim.bo[buf]
	bo.buftype = 'nofile'
	bo.modeline = false
	bo.modifiable = false
	bo.swapfile = false
	bo.undolevels = -1

	buf_map(buf, 'q', '<C-W>c')
	buf_map(buf, 'gf', M.goto_object)
	buf_map(buf, '<CR>', M.goto_object)
	buf_map(buf, 'u', goto_parent_tree)
	buf_map(buf, '~', goto_ancestor)
	buf_map(buf, '^', goto_parent)
end

function M.autocmd(opts)
	local buf = opts.buf
	local rev = M.buf_get_rev(0)

	M.buf_init(buf)
	Repository.from_current_buf()

	M.buf_pipe(buf, {
		args = {
			'show',
			'--compact-summary',
			'--patch',
			'--format=format:commit %H%d%nparent %P%ntree %T%nAuthor: %aN <%aE>%nDate:   %aD%nCommit: %cN <%cE>%n%n    %s%n%-b%n',
			rev,
			-- XXX: `git show X~` shows "X is a tree, not a commit" error message
			-- multiple times without '--'.
			'--',
		},
		callback = function(success)
			if success then
				return buf_detect_object_filetype(buf, rev)
			else
				vim.bo[buf].filetype = 'giterror'
			end
		end,
	})
end

return M
