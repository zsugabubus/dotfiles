local utils = require('mp.utils')

local SUBTITLE_EXTS = { 'srt', 'lrc', 'txt', 'vtt' }

local function pesc(s)
	return s:gsub('([^%w])', '%%%1')
end

local function remove_ext(filename)
	return filename:match('^(.+)%..+$') or filename
end

local function add_subtitle(file)
	if file:find('%.txt$') then
		local tmpfile = os.tmpname() .. '.lrc'
		local f = assert(io.open(file, 'r'))
		local tmp = assert(io.open(tmpfile, 'w'))
		assert(tmp:write('[0:0.0] '))
		assert(tmp:write(f:read('*all')))
		assert(tmp:close())
		assert(f:close())
		mp.commandv('sub-add', tmpfile)
		os.remove(tmpfile)
	else
		mp.commandv('sub-add', file)
	end
end

local function patterns_from_filename(filename)
	local patterns = {}

	local function add_pattern(pattern)
		for _, ext in pairs(SUBTITLE_EXTS) do
			table.insert(patterns, ('^%s%%.%s$'):format(pattern, ext))
		end
	end

	add_pattern(pesc(remove_ext(filename)) .. '.*')

	local season, episode = filename:match('[sS]0*(%d+)[eE]0*(%d+)')
	if not season then
		season, episode = filename:match('0*(%d+)[xX]0*(%d+)')
	end
	if season then
		add_pattern(('.*[sS]0*%s[eE]0*%s.*'):format(season, episode))
		add_pattern(('.*%%D%s[xX]0*%s%%D.*'):format(season, episode))
	end

	return patterns
end

local function search(path, patterns)
	local file_count = 0

	for _, file in ipairs(utils.readdir(path, 'files') or {}) do
		file_count = file_count + 1
		for _, pattern in ipairs(patterns) do
			if file:find(pattern) then
				add_subtitle(utils.join_path(path, file))
			end
		end
	end

	if file_count <= 1 then
		for _, dir in ipairs(utils.readdir(path, 'dirs') or {}) do
			search(utils.join_path(path, dir), patterns)
		end
	end
end

local function has_video()
	for _, track in ipairs(mp.get_property_native('track-list')) do
		if track.type == 'video' and not track.albumart then
			return true
		end
	end
end

mp.register_event('file-loaded', function()
	if not has_video() then
		return
	end

	local path = mp.get_property('path')
	if path:find('://') then
		return
	end

	local dirname, filename = utils.split_path(path)
	local patterns = patterns_from_filename(filename)

	for _, subdir in ipairs(mp.get_property_native('sub-file-paths')) do
		search(utils.join_path(dirname, subdir), patterns)
	end
end)

mp.set_property_native('sub-auto', false)
