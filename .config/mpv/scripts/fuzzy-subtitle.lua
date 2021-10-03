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

	for i, subdir in pairs(mp.get_property_native('sub-file-paths')) do
		walk(dirname .. '/' .. subdir, pats)
	end
end)

function addpat(pats, pat)
	if pat == nil then
		return
	end

	for i, ext in pairs({'srt', 'lrc', 'txt'}) do
		table.insert(pats, pat .. '%.' .. ext .. '$')
	end
end

function text2pat(text)
	return text:gsub('([^%w])', '%%%1')
end

function walk(path, pats)
	local nfiles = 0
	for i, file in pairs(utils.readdir(path, 'files') or {}) do
		nfiles = nfiles + 1

		for i, pattern in pairs(pats) do

			if file:find(pattern) ~= nil then
				local gen = file:find('%.txt$') ~= nil
				if gen then
					local f = io.open(file, 'r')
					file = tmp_file .. '.lrc'
					local t = io.open(file, 'w')
					t:write('[0:0.0] ')
					t:write(f:read('*all'))
					f:close()
					t:close()
				end

				mp.commandv('sub-add', file)

				if gen then
					os.remove(file)
				end
			end
		end
	end
	if nfiles <= 1 then
		for i, dir in pairs(utils.readdir(path, 'dirs') or {}) do
			walk(path .. '/' .. dir, pats)
		end
	end
end
