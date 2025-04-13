local utils = require('mp.utils')

local SUBTITLE_EXTENSIONS = { 'srt', 'lrc', 'txt' }

local XDG_CACHE_DIR = (
	os.getenv('XDG_CACHE_DIR') or utils.join_path(os.getenv('HOME'), '.cache')
)
local TMP_PREFIX =
	utils.join_path(XDG_CACHE_DIR, 'mpv-' .. mp.get_script_name())

local function pesc(s)
	return s:gsub('([^%w])', '%%%1')
end

local function add_subtitle(file)
	local tmp_file
	if file:find('%.txt$') then
		tmp_file = TMP_PREFIX .. '.lrc'

		local f = io.open(file, 'r')
		local tmp = io.open(tmp_file, 'w')
		tmp:write('[0:0.0] ')
		tmp:write(f:read('*all'))
		tmp:close()
		f:close()
	end

	mp.commandv('sub-add', tmp_file or file)

	if tmp_file then
		os.remove(tmp_file)
	end
end

local function patterns_from_filename(filename)
	local patterns = {}

	local function add_pattern(pattern)
		for _, ext in pairs(SUBTITLE_EXTENSIONS) do
			local full_pattern = ('^%s%%.%s$'):format(pattern, ext)
			table.insert(patterns, full_pattern)
		end
	end

	add_pattern(pesc(filename))

	local without_ext = filename:match('^(.+)%..+$')
	if without_ext then
		add_pattern(pesc(without_ext))
	end

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
	local num_files = 0
	for _, file in ipairs(utils.readdir(path, 'files') or {}) do
		num_files = num_files + 1
		for _, pattern in ipairs(patterns) do
			if file:find(pattern) then
				add_subtitle(utils.join_path(path, file))
			end
		end
	end

	if num_files <= 1 then
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
