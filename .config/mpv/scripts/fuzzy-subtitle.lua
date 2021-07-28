local utils = require 'mp.utils'

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
		addpat(pats, '[sS]0*'..serno..'[eE]0*'..epno..'.*')
	end

	for i,subdir in pairs(mp.get_property_native('sub-file-paths')) do
		walk(dirname..'/'..subdir, pats)
	end
end)

function addpat(pats, pat)
	if pat == nil then
		return
	end

	for i,ext in pairs({'srt', 'lrc', 'txt'}) do
		table.insert(pats, pat..'%.'..ext..'$')
	end
end

function text2pat(text)
	return text:gsub('([^%w])', '%%%1')
end

function walk(path, pats)
	for i,file in pairs(utils.readdir(path, 'files') or {}) do
		for i,pattern in pairs(pats) do
			if file:find(pattern) ~= nil then
				mp.commandv('sub-add', file)
			end
		end
	end
	for i,dir in pairs(utils.readdir(path, 'dirs') or {}) do
		walk(path..'/'..dir, pats)
	end
end
