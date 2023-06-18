local M = {}
local uv = vim.loop

local function read_start_buf(stream, mode, callback)
	if mode == 'buffered' then
		local buf = require('string.buffer'):new()
		uv.read_start(stream, function(err, data)
			assert(not err, err)
			if data then
				return buf:put(data)
			else
				return callback(buf:tostring())
			end
		end)
	elseif mode == 'stream' then
		uv.read_start(stream, function(err, data)
			assert(not err, err)
			return callback(data)
		end)
	elseif mode == 'line' then
		local partial = ''
		uv.read_start(stream, function(err, data)
			assert(not err, err)
			if data then
				for line, eol in string.gmatch(partial .. data, '([^\n]*)(\n?)') do
					if eol == '' then
						partial = line
						return
					else
						callback(line)
					end
				end
			else
				callback(partial)
				return callback()
			end
		end)
	else
		assert(false, mode)
	end
end

function M.make_args(repo, args, with_argv0)
	local t = {}

	if with_argv0 then
		table.insert(t, 'git')
	end

	table.insert(t, '--no-optional-locks')
	table.insert(t, '--literal-pathspecs')

	if repo.dir then
		table.insert(t, '-C')
		table.insert(t, repo.dir)
	else
		table.insert(t, '--git-dir')
		table.insert(t, repo.git_dir)
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

function M.run(repo, opts)
	local args = M.make_args(repo, opts.args)

	local stdout = uv.new_pipe()
	local stderr = opts.on_stderr and uv.new_pipe() or nil

	local handle = uv.spawn('git', {
		args = args,
		stdio = { nil, stdout, stderr },
	}, function(code)
		if opts.callback then
			opts.callback(code == 0)
		end
	end)

	read_start_buf(stdout, opts.stdout_mode or 'buffered', opts.on_stdout)
	if opts.on_stderr then
		read_start_buf(stderr, 'buffered', function(data)
			if #data > 1 then
				-- Trim "\n".
				opts.on_stderr(string.sub(data, 1, -2))
			end
		end)
	end

	return handle
end

function M.buf_run(buf, repo, opts)
	local process = M.run(repo, opts)

	vim.api.nvim_create_autocmd('BufDelete', {
		buffer = buf,
		once = true,
		callback = function()
			uv.process_kill(process, 'KILL')
		end,
	})

	return process
end

return M
