local api = vim.api
local bo = vim.bo
local fn = vim.fn

local autocmd = api.nvim_create_autocmd
local echoerr = api.nvim_err_writeln
local shesc = fn.shellescape

local group = api.nvim_create_augroup('explorer.ssh', {})

local function echomsg(...)
	api.nvim_echo({ { string.format(...), 'Normal' } }, true, {})
end

local function parse_opts(opts)
	local destination, path = opts.match:match('ssh://([^/]*)(.*)')
	if path == '' then
		return destination, '/', false
	end
	return destination, path:gsub('//$', '/'), path:match('//$')
end

autocmd('BufReadCmd', {
	group = group,
	pattern = 'ssh://*',
	nested = true,
	callback = function(opts)
		local destination, path, recursive = parse_opts(opts)

		bo.buftype = 'nofile'
		bo.swapfile = false

		local cmdline = {
			'ssh',
			'--',
			destination,
			([[
				if test -f %s; then
					echo file
					if test -w %s; then
						echo writable
					else
						echo readonly
					fi
					cat %s
				elif test -d %s; then
					echo dir
					echo writable
					%s %s 2>/dev/null ||:
				elif test -e %s; then
					echo other
					echo readonly
				else
					echo new
					echo writable
				fi
				]]):format(
				shesc(path),
				shesc(path),
				shesc(path),
				shesc(path),
				recursive and 'find' or 'ls -pa',
				shesc(path),
				shesc(path)
			),
		}

		local output = fn.systemlist(cmdline)
		local kind = table.remove(output, 1)
		local writable = table.remove(output, 1)

		if vim.v.shell_error ~= 0 then
			bo.readonly = true
			echoerr("Can't read file: " .. vim.trim(table.concat(output, '\n')))
			return
		end

		if kind == 'dir' then
			local prefix = 'ssh://'
				.. destination
				.. (recursive and '' or (path .. '/'):gsub('//$', '/'))

			-- Eat "." and "..".
			if not recursive then
				table.remove(output, 1)
				table.remove(output, 1)
			end

			for i, path in ipairs(output) do
				output[i] = prefix .. output[i]
			end
		end

		api.nvim_buf_set_lines(0, 0, -1, true, output)

		bo.readonly = writable == 'readonly'

		if kind == 'file' or kind == 'new' then
			local filetype, on_detect = vim.filetype.match({
				buf = 0,
				filename = path,
			})

			bo.buftype = 'acwrite'
			bo.filetype = filetype or ''

			if on_detect then
				on_detect(0)
			end
		elseif kind == 'dir' then
			bo.filetype = 'directory'
			bo.modeline = false
		else
			bo.filetype = ''
		end
	end,
})

autocmd('BufWriteCmd', {
	group = group,
	pattern = 'ssh://*',
	nested = true,
	callback = function(opts)
		local destination, path = parse_opts(opts)
		local tmp_path = path .. '~'

		local cmdline = {
			'ssh',
			'--',
			destination,
			('test -e %s || echo new && cat >%s && mv %s %s'):format(
				shesc(path),
				shesc(tmp_path),
				shesc(tmp_path),
				shesc(path)
			),
		}

		local output = fn.system(cmdline, opts.buf)
		local new = output == 'new\n'

		if vim.v.shell_error ~= 0 then
			echoerr("Can't write file: " .. vim.trim(output))
			return
		end

		vim.bo.modified = false

		echomsg(
			'"%s"%s %dL, %dB written on %s',
			path,
			new and ' [New]' or '',
			api.nvim_buf_line_count(0),
			fn.wordcount().bytes,
			destination
		)
	end,
})

autocmd('BufFilePost', {
	group = group,
	pattern = 'ssh://*',
	nested = true,
	callback = function()
		vim.cmd.edit()
	end,
})
