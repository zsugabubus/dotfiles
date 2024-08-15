local api = vim.api
local bo = vim.bo
local fn = vim.fn

local group = api.nvim_create_augroup('archive', {})

local function read_system(cmdline)
	api.nvim_buf_set_lines(0, 0, -1, true, fn.systemlist(cmdline))
	bo.buftype = 'nofile'
	bo.readonly = true
	bo.swapfile = false
end

local function archive(patterns, list_cmdline, extract_cmdline)
	api.nvim_create_autocmd('BufReadCmd', {
		group = group,
		pattern = patterns,
		nested = true,
		callback = function(opts)
			vim.b.did_archive = true
			local archive = opts.file
			read_system(list_cmdline(archive))
			bo.modeline = false
			if vim.v.shell_error == 0 then
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

	api.nvim_create_autocmd('BufReadCmd', {
		group = group,
		pattern = string.gsub(patterns, ',', '//*,'),
		nested = true,
		callback = function(opts)
			vim.b.did_archive = true
			local match = opts.match
			for pattern in string.gmatch(patterns, '[^,]+') do
				local ext = vim.pesc(string.match(pattern, '^%*(.*)'))
				local pattern = string.format('^(.-%s)//(.*)', ext)
				local archive, member = string.match(match, pattern)
				if archive and member == '' then
					read_system(extract_cmdline(archive))
					bo.modeline = false
					return
				elseif archive then
					read_system(extract_cmdline(archive, member))
					if vim.v.shell_error ~= 0 then
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
	api.nvim_create_autocmd('BufReadCmd', {
		group = group,
		pattern = pattern,
		nested = true,
		callback = function(opts)
			if vim.b.did_archive then
				return
			end
			local file = opts.match
			local cmdline = { prog, '-cd', '--', file }
			api.nvim_buf_set_lines(0, 0, -1, true, fn.systemlist(cmdline))
			if vim.v.shell_error ~= 0 then
				bo.modeline = false
				bo.buftype = 'nofile'
				bo.filetype = ''
				return
			end
			bo.modeline = true
			bo.buftype = 'acwrite'
			local filetype, on_detect = vim.filetype.match({
				buf = 0,
				filename = string.sub(file, 1, -#pattern),
			})
			bo.filetype = filetype or ''
			if on_detect then
				on_detect(0)
			end
		end,
	})

	api.nvim_create_autocmd('BufWriteCmd', {
		group = group,
		pattern = pattern,
		nested = true,
		callback = function(opts)
			local file = opts.match
			local tmpfile = file .. '~'
			local cmdline = string.format('%s > %s', prog, fn.shellescape(tmpfile))
			local input = api.nvim_buf_get_text(0, 0, 0, -1, -1, {})
			table.insert(input, '') -- Ensure ends with <EOL>.
			local err = fn.system(cmdline, input)
			local ok = vim.v.shell_error == 0
			if ok then
				ok, err = os.rename(tmpfile, file)
			end
			if not ok then
				os.remove(tmpfile)
			end
			if not ok then
				api.nvim_echo({ { err, 'ErrorMsg' } }, true, {})
				return
			end
			bo.modified = false
			api.nvim_echo({
				{
					string.format('"%s" written with %s', opts.file, prog),
					'Normal',
				},
			}, true, {})
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
