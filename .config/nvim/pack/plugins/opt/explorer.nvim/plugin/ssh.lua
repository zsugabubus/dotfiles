local api = vim.api
local bo = vim.bo
local fn = vim.fn

local shesc = fn.shellescape

local group = api.nvim_create_augroup('explorer.ssh', {})
local pattern = 'ssh://*'

local function parse_opts(opts)
	local destination, path = string.match(opts.match, 'ssh://([^/]*)(.*)')
	if path == '' then
		return destination, '/', false
	end
	return destination, string.gsub(path, '//$', '/'), string.match(path, '//$')
end

local function echo(hl_group, ...)
	api.nvim_echo({ { string.format(...), hl_group } }, true, {})
end

api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = pattern,
	nested = true,
	callback = function(opts)
		local destination, path, recursive = parse_opts(opts)
		bo.buftype = 'nofile'
		bo.swapfile = false
		local cmdline = {
			'ssh',
			'--',
			destination,
			string.format(
				[[
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
				]],
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
			echo(
				'ErrorMsg',
				"Can't read file: %s",
				vim.trim(table.concat(output, '\n'))
			)
			return
		end
		if kind == 'dir' then
			local prefix = 'ssh://'
				.. destination
				.. (recursive and '' or string.gsub(path .. '/', '//$', '/'))
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
			bo.buftype = 'acwrite'
			local filetype, on_detect = vim.filetype.match({
				buf = 0,
				filename = path,
			})
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

api.nvim_create_autocmd('BufWriteCmd', {
	group = group,
	pattern = pattern,
	nested = true,
	callback = function(opts)
		local destination, path = parse_opts(opts)
		local tmp_path = path .. '~'
		local cmdline = {
			'ssh',
			'--',
			destination,
			string.format(
				'test -e %s || echo && cat >%s && mv %s %s',
				shesc(path),
				shesc(tmp_path),
				shesc(tmp_path),
				shesc(path)
			),
		}
		local output = fn.system(cmdline, opts.buf)
		if vim.v.shell_error ~= 0 then
			echo('ErrorMsg', "Can't write file: %s", vim.trim(output))
			return
		end
		vim.bo.modified = false
		local new = output == '\n\n'
		echo(
			'Normal',
			'"%s"%s %dL, %dB written on %s',
			path,
			new and ' [New]' or '',
			api.nvim_buf_line_count(0),
			fn.wordcount().bytes,
			destination
		)
	end,
})

api.nvim_create_autocmd('BufFilePost', {
	group = group,
	pattern = pattern,
	nested = true,
	callback = function()
		vim.cmd.edit()
	end,
})
