local Repository = require('git.repository')
local buffer = require('git.buffer')
local revision = require('git.revision')
local utils = require('git.utils')

local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

local function alias(repo, name)
	if
		utils.execute(utils.make_args(repo, {
			'config',
			'alias.' .. name,
		}))
	then
		return name
	end
end

local function handle_user_command(opts)
	if opts.args ~= '' then
		s = opts.args
	elseif opts.range ~= 0 then
		local rev, path
		local git_dir, rev_path = buffer.buf_get_rev(0)
		if rev_path then
			rev, path = revision.split_path(rev_path)
		else
			local repo = Repository.from_path_or_current_buf(git_dir)
			repo = Repository.await(repo)
			utils.ensure_work_tree(repo)
			rev, path = '@', fn.expand('%:p'):sub(#repo.work_tree + 2)
		end

		s = ('%s%s%s:%s:%d-%d'):format(
			git_dir or '',
			git_dir and '//' or '',
			rev,
			path,
			opts.line1,
			opts.line2
		)
	else
		s = '@'
	end

	local buf = fn.bufnr('git-log://' .. s, true)
	vim.b[buf].git_log_limit = opts.bang and -1 or 100
	cmd.buffer(buf)
end

local function handle_complete(...)
	return require('git.show').handle_complete(...)
end

local function handle_read_autocmd(opts)
	buffer.buf_init(0)

	local git_dir, rev_path_range = buffer.buf_get_rev(0)
	local repo = Repository.from_path_or_current_buf(git_dir)
	local rev, path_range = revision.split_path(rev_path_range)

	local path, start_lnum, end_lnum = path_range:match('^(.*):(%d*)%-(%d*)$')
	if not path then
		path = path_range
	end

	vim.b.git_use_preview = true

	local has_AnsiEsc = fn.exists(':AnsiEsc') == 2

	local args = {
		alias(repo, path ~= '' and 'log-vim-patch' or 'log-vim') or 'log',
		'-n' .. (vim.b.git_log_limit or -1),
		rev,
	}

	if has_AnsiEsc then
		table.insert(args, '--color=always')
	end

	if path ~= '' then
		repo = Repository.await(repo)
		local full_path = repo.work_tree .. '/' .. path

		if start_lnum then
			table.insert(args, ('-L%d,%d:%s'):format(start_lnum, end_lnum, full_path))
		else
			table.insert(args, '--patch')
			table.insert(args, '--')
			table.insert(args, full_path)
		end
	end

	local bo = vim.bo

	local lines = vim.fn.systemlist(utils.make_args(repo, args))

	-- Avoid useless 'foldexpr' recalculations.
	if has_AnsiEsc then
		vim.wo[0][0].foldmethod = 'manual'
	end

	bo.modifiable = true
	api.nvim_buf_set_lines(0, 0, -1, true, lines)
	if has_AnsiEsc then
		cmd.AnsiEsc()
	end
	bo.modifiable = false

	buffer.fold_hunks()
end

return {
	handle_user_command = handle_user_command,
	handle_complete = handle_complete,
	handle_read_autocmd = handle_read_autocmd,
}
