local utils = require('mp.utils')
local tmp_file = (os.getenv('TMPDIR') or '/tmp') .. '/' .. mp.get_script_name()

mp.register_event('start-file', function()
	local filename = mp.get_property('path')
	if filename == nil then
		return
	end
	local dirname, basename = utils.split_path(filename)

	local pats = {}

	local basename_pat = text2pat(basename)
	addpat(pats, basename_pat)
	addpat(pats, string.match(basename_pat, '(.*)%%%..+'))

	local serno, epno = string.match(basename, '[sS]0*(%d+)[eE]0*(%d+)')
	if serno ~= nil and epno ~= nil then
		addpat(pats, '[sS]0*' .. serno .. '[eE]0*' .. epno .. '.*')
	end

	for _, subdir in ipairs(mp.get_property_native('sub-file-paths')) do
		walk(dirname .. '/' .. subdir, pats)
	end
end)

function addpat(pats, pat)
	if pat == nil then
		return
	end

	for _, ext in pairs({'srt', 'lrc', 'txt'}) do
		table.insert(pats, pat .. '%.' .. ext .. '$')
	end
end

function text2pat(text)
	return text:gsub('([^%w])', '%%%1')
end

function walk(path, pats)
	local nfiles = 0
	for _, file in ipairs(utils.readdir(path, 'files') or {}) do
		nfiles = nfiles + 1

		for _, pattern in ipairs(pats) do

			if file:find(pattern) ~= nil then
				local gen = file:find('%.txt$') ~= nil
				if gen then
					mp.msg.info('Generating subtitle from', file)
					local f = io.open(file, 'r')
					file = tmp_file .. '.lrc'
					local t = io.open(file, 'w')
					t:write('[0:0.0] ')
					t:write(f:read('*all'))
					f:close()
					t:close()
				end

				mp.msg.info('Adding subtitle from', file)
				mp.commandv('sub-add', file)

				if gen then
					os.remove(file)
				end
			end
		end
	end
	if nfiles <= 1 then
		for _, dir in ipairs(utils.readdir(path, 'dirs') or {}) do
			walk(path .. '/' .. dir, pats)
		end
	end
end
