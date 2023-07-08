local M = {}

local cli = require('git.cli')

local uv = vim.loop

local redraw_timer = uv.new_timer()

local repo_by_path = {}
local repo_by_id = {}

local function redraw_status_inner()
	for _, repo in pairs(repo_by_id) do
		repo.live = false
	end
	vim.cmd.redrawstatus()
end

local function redraw_status_callback()
	vim.schedule(redraw_status_inner)
end

local function redraw_status()
	if not uv.is_active(redraw_timer) then
		uv.timer_start(redraw_timer, 5, 0, redraw_status_callback)
	end
end

local function put_flag(buf, name, value)
	if value == true or value == 1 then
		return buf:put(name)
	elseif value and value > 1 then
		return buf:put(name, value)
	end
end

function update_statusline(repo)
	local buf = require('string.buffer').new()

	put_flag(buf, 'BARE:', repo.bare)
	put_flag(buf, 'detached ', repo.detached)
	buf:put(repo.head or 'undefined')
	put_flag(buf, '+', repo.staged)
	put_flag(buf, '*', repo.modified)
	put_flag(buf, '$', repo.stashed)
	if repo.ahead == 0 and repo.behind == 0 then
		buf:put('=')
	else
		put_flag(buf, '<', repo.behind)
		put_flag(buf, '>', repo.ahead)
	end
	if repo.operation then
		buf:put('|', repo.operation)
		if repo.step then
			buf:put(' ', repo.step, '/', repo.total)
		end
	end

	local s = buf:tostring()
	if s ~= repo.statusline then
		repo.statusline = s
		redraw_status()
	end
end

local function update_head(repo)
	cli.run(repo, {
		args = {
			'symbolic-ref',
			'--short',
			'HEAD',
		},
		on_stdout = function(data)
			if data ~= '' then
				-- Trim "\n".
				repo.head = string.sub(data, 1, -2)
				repo.detached = false
				return update_statusline(repo)
			end

			repo.detached = true
			cli.run(repo, {
				args = {
					'name-rev',
					'--name-only',
					'--always',
					'--no-undefined',
					'HEAD',
				},
				on_stdout = function(data)
					if data == '' then
						repo.head = 'undefined'
					else
						-- Trim "\n".
						repo.head = string.sub(data, 1, -2)
					end
					return update_statusline(repo)
				end,
			})
		end,
	})
end

local function update_stashed(repo)
	cli.run(repo, {
		args = {
			'rev-list',
			'--walk-reflogs',
			'--count',
			'refs/stash',
		},
		on_stdout = function(data)
			repo.stashed = tonumber(data) or 0
			return update_statusline(repo)
		end,
	})
end

local function update_ahead_behind(repo)
	cli.run(repo, {
		args = {
			'rev-list',
			'--count',
			'--left-right',
			'--count',
			'@{upstream}...@',
		},
		on_stdout = function(data)
			local behind, ahead = string.match(data, '(%d+)\t(%d+)')
			repo.behind = tonumber(behind)
			repo.ahead = tonumber(ahead)
			return update_statusline(repo)
		end,
	})
end

local function read_all(path, callback)
	return uv.fs_open(path, 'r', 0, function(_, fd)
		if not fd then
			return callback()
		end
		return uv.fs_read(fd, 64, function(_, data)
			uv.fs_close(fd, function(err, success)
				assert(not err, err)
				assert(success)
			end)
			return callback(data)
		end)
	end)
end

local function update_operation(repo)
	local i = 6

	local function step(operation, step, total)
		if operation and step and total then
			repo.operation, repo.step, repo.total = operation, step, total
			return update_statusline(repo)
		elseif operation then
			repo.operation, repo.step, repo.total = operation
			return update_statusline(repo)
		end

		i = i - 1
		if i == 0 then
			repo.operation, repo.step, repo.total = nil
			return update_statusline(repo)
		end
	end

	uv.fs_access(repo.git_dir .. '/REVERT_HEAD', 'r', function(_, permission)
		return step(permission and 'REVERT')
	end)

	uv.fs_access(repo.git_dir .. '/BISECT_LOG', 'r', function(_, permission)
		return step(permission and 'BISECT')
	end)

	uv.fs_access(repo.git_dir .. '/CHERRY_PICK_HEAD', 'r', function(_, permission)
		return step(permission and 'CHERRY-PICK')
	end)

	uv.fs_access(repo.git_dir .. '/MERGE_HEAD', 'r', function(_, permission)
		return step(permission and 'MERGE')
	end)

	uv.fs_access(repo.git_dir .. '/rebase-merge', 'r', function(_, permission)
		if permission then
			read_all(repo.git_dir .. '/rebase-merge/msgnum', function(data)
				local k = tonumber(data)
				read_all(repo.git_dir .. '/rebase-merge/end', function(data)
					local n = tonumber(data)
					return step('REBASE', k, n)
				end)
			end)
		else
			return step()
		end
	end)

	uv.fs_access(repo.git_dir .. '/rebase-apply', 'r', function(_, permission)
		if permission then
			read_all(repo.git_dir .. '/rebase-apply/next', function(data)
				local k = tonumber(data)
				read_all(repo.git_dir .. '/rebase-apply/last', function(data)
					local n = tonumber(data)
					return step('REBASE', k, n)
				end)
			end)
		else
			return step()
		end
	end)
end

local function update_modified(repo)
	if repo.work_tree then
		cli.run(repo, {
			args = {
				'status',
				'--porcelain',
			},
			on_stdout = function(data)
				data = '\n' .. data
				repo.staged = string.match(data, '\n[MARC]') ~= nil
				repo.modified = string.match(data, '\n.[MARC]') ~= nil
				return update_statusline(repo)
			end,
		})
	end
end

local function update_outdated(repo)
	if repo.outdated.head then
		update_head(repo)
		update_ahead_behind(repo)
	end
	if repo.outdated.index then
		update_modified(repo)
		update_stashed(repo)
	end
	if repo.outdated.operation then
		update_operation(repo)
	end
	repo.outdated = {}
end

function M.from_path(path)
	local repo = repo_by_path[path]
	if repo then
		return repo
	end

	local repo = {
		dir = path,
		statusline = '',
		outdated = {},
	}
	repo_by_path[path] = repo

	cli.run(repo, {
		args = {
			'rev-parse',
			'--is-bare-repository',
			'--absolute-git-dir',
			'--show-toplevel',
		},
		on_stdout = function(data)
			if data == '' then
				return
			end

			local bare, git_dir, work_tree = unpack(vim.split(data, '\n', {
				trimempty = true,
			}))

			local repo = {
				git_dir = git_dir,
				work_tree = work_tree,
				bare = bare == 'true',
				statusline = '',
				outdated = {},
			}

			local id = repo.git_dir .. '\0' .. (repo.work_tree or '')
			local existing_repo = repo_by_id[id]
			if existing_repo then
				repo_by_path[path] = existing_repo
				return
			end

			repo_by_id[id] = repo
			repo_by_path[path] = repo
			repo_by_path[work_tree or git_dir] = repo

			local timer = uv.new_timer()

			repo.fs_event = uv.new_fs_event()
			uv.fs_event_start(repo.fs_event, git_dir, {}, function(err, filename)
				if filename == 'HEAD' or filename == 'HEAD.lock' then
					repo.outdated.head = true
				elseif filename == 'index' then
					repo.outdated.index = true
				elseif
					filename == 'rebase-merge'
					or filename == 'rebase-apply'
					or filename == 'MERGE_HEAD'
					or filename == 'CHERRY_PICK_HEAD'
					or filename == 'REVERT_HEAD'
					or filename == 'BISECT_LOG'
				then
					repo.outdated.operation = true
				else
					return
				end

				if not repo.live then
					return
				end

				if uv.is_active(timer) then
					return
				end

				uv.timer_start(timer, 100, 0, function()
					update_outdated(repo)
				end)
			end)

			update_head(repo)
			update_ahead_behind(repo)
			update_modified(repo)
			update_stashed(repo)
			update_operation(repo)
		end,
	})

	return repo
end

function M.from_buf(buf)
	return M.from_path(assert(vim.b[buf].git_dir))
end

function M.from_current_buf()
	local dir = vim.b.git_dir
	if not dir then
		if vim.bo.buftype == '' then
			dir = vim.fn.expand('%:p:h')
		else
			dir = vim.fn.getcwd()
		end
		vim.b.git_dir = dir
	end
	return M.from_path(dir)
end

function is_status_enabled(buf)
	local buftype = vim.bo[buf].buftype
	if buftype == 'help' or buftype == 'quickfix' then
		return false
	end

	local bufname = vim.api.nvim_buf_get_name(buf)
	if
		string.sub(bufname, 1, 6) == 'man://'
		or string.sub(bufname, 1, 4) == '/tmp'
	then
		return false
	end

	return true
end

function M.status()
	if not is_status_enabled(0) then
		return ''
	end

	local repo = M.from_current_buf()

	if not repo.live then
		repo.live = true
		update_outdated(repo)
	end

	return repo.statusline
end

return M
