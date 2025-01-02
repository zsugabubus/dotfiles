local api = vim.api
local bo = vim.bo
local fn = vim.fn

local autocmd = api.nvim_create_autocmd
local echoerr = api.nvim_err_writeln

local group = api.nvim_create_augroup('archive', {})

local function echomsg(s)
	api.nvim_echo({ { s, 'Normal' } }, true, {})
end

local function read_system(cmdline)
	bo.buftype = 'nofile'
	bo.swapfile = false
	local lines = fn.systemlist(cmdline)
	if vim.v.shell_error ~= 0 then
		echoerr(table.concat(lines, '\n'))
		return false
	end
	api.nvim_buf_set_lines(0, 0, -1, true, lines)
	bo.readonly = true
	return true
end

local function archive(patterns, list_cmdline, extract_cmdline)
	autocmd('BufReadCmd', {
		group = group,
		pattern = patterns,
		nested = true,
		callback = function(opts)
			vim.b.did_archive = true
			local archive = opts.file
			bo.modeline = false
			if read_system(list_cmdline(archive)) then
				bo.filetype = 'archive'
			else
				bo.filetype = ''
			end
			api.nvim_buf_set_keymap(0, 'n', 'gf', '', {
				nowait = true,
				callback = function()
					vim.cmd.edit(
						fn.fnameescape(archive .. '//' .. api.nvim_get_current_line())
					)
				end,
			})
			api.nvim_buf_set_keymap(0, 'n', '<CR>', 'gf', { nowait = true })
		end,
	})

	autocmd('BufReadCmd', {
		group = group,
		pattern = patterns:gsub(',', '//*,'),
		nested = true,
		callback = function(opts)
			vim.b.did_archive = true
			for pattern in patterns:gmatch('[^,]+') do
				local ext = vim.pesc(pattern:match('^%*(.*)'))
				local pattern = ('^(.-%s)//(.*)'):format(ext)
				local archive, member = opts.match:match(pattern)
				if archive and member == '' then
					read_system(extract_cmdline(archive))
					bo.modeline = false
					return
				elseif archive then
					if not read_system(extract_cmdline(archive, member)) then
						bo.modeline = false
						bo.filetype = ''
						return
					end
					bo.modeline = true
					local filetype, on_detect = vim.filetype.match({
						buf = 0,
						filename = member,
					})
					bo.filetype = filetype or ''
					if on_detect then
						on_detect(0)
					end
					return
				end
			end
		end,
	})
end

local function compress(pattern, prog)
	autocmd('BufReadCmd', {
		group = group,
		pattern = pattern,
		nested = true,
		callback = function(opts)
			if vim.b.did_archive then
				return
			end
			local file = opts.match
			local cmdline = { prog, '-cd', '--', file }
			local lines = fn.systemlist(cmdline)
			if vim.v.shell_error ~= 0 then
				if not lines[#lines]:find(': No such file or directory$') then
					echoerr(table.concat(lines, '\n'))
					bo.modeline = false
					bo.buftype = 'nofile'
					bo.filetype = ''
					return
				end
			else
				api.nvim_buf_set_lines(0, 0, -1, true, lines)
			end
			bo.modeline = true
			bo.buftype = 'acwrite'
			local filetype, on_detect = vim.filetype.match({
				buf = 0,
				filename = file:sub(1, -#pattern),
			})
			bo.filetype = filetype or ''
			if on_detect then
				on_detect(0)
			end
		end,
	})

	autocmd('BufWriteCmd', {
		group = group,
		pattern = pattern,
		nested = true,
		callback = function(opts)
			local file = opts.match
			local tmpfile = file .. '~'
			local cmdline = ('%s > %s'):format(prog, fn.shellescape(tmpfile))
			local input = api.nvim_buf_get_text(0, 0, 0, -1, -1, {})
			table.insert(input, '') -- Ensure ends with <EOL>.
			local err = fn.system(cmdline, input)
			local ok = vim.v.shell_error == 0
			if ok then
				ok, err = os.rename(tmpfile, file)
			end
			if not ok then
				os.remove(tmpfile)
				echoerr(err)
				return
			end
			bo.modified = false
			echomsg(('"%s" written with %s'):format(opts.file, prog))
		end,
	})
end

-- Extension lists are taken from tarPlugin and zipPlugin.
archive(
	'*.tar.gz,*.tar,*.lrp,*.tar.bz2,*.tar.Z,*.tbz,*.tgz,*.tar.lzma,*.tar.xz,*.txz,*.tar.zst,*.tzs,',
	function(archive)
		return { 'tar', 'taf', archive }
	end,
	function(archive, member)
		return { 'tar', 'xafO', archive, '--no-wildcards', '--', member }
	end
)

archive(
	'*.zip,*.aar,*.apk,*.celzip,*.crtx,*.docm,*.docx,*.dotm,*.dotx,*.ear,*.epub,*.gcsx,*.glox,*.gqsx,*.ja,*.jar,*.kmz,*.odb,*.odc,*.odf,*.odg,*.odi,*.odm,*.odp,*.ods,*.odt,*.otc,*.otf,*.otg,*.oth,*.oti,*.otp,*.ots,*.ott,*.oxt,*.potm,*.potx,*.ppam,*.ppsm,*.ppsx,*.pptm,*.pptx,*.sldx,*.thmx,*.vdw,*.war,*.wsz,*.xap,*.xlam,*.xlam,*.xlsb,*.xlsm,*.xlsx,*.xltm,*.xltx,*.xpi,',
	function(archive)
		return { 'zipinfo', '-1', archive }
	end,
	function(archive, member)
		return { 'unzip', '-qc', '--', archive, member }
	end
)

compress('*.gz', 'gzip')
compress('*.bz2', 'bzip2')
compress('*.Z', 'uncompress')
compress('*.lzma', 'lzma')
compress('*.xz', 'xz')
compress('*.lz', 'lzip')
compress('*.zst', 'zstd')
compress('*.br', 'brotli')
compress('*.lzo', 'lzop')
