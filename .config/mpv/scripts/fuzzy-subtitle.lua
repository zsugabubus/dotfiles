local utils = require 'mp.utils'

local SUBTITLE_EXTENSIONS = { 'srt', 'lrc', 'txt' }

local CODEC_BLACKLIST = {
	mp3 = true,
	flac = true,
}

local XDG_CACHE_DIR = (
	os.getenv('XDG_CACHE_DIR') or
	utils.join_path(os.getenv('HOME'), '.cache')
)
local TMP_PREFIX = utils.join_path(
	XDG_CACHE_DIR,
	'mpv-' .. mp.get_script_name()
)

mp.msg.debug('Temporary file prefix', TMP_PREFIX)

local function str2pattern(s)
	return string.gsub(s, '([^%w])', '%%%1')
end

local function add_subtitle(file)
	mp.msg.info('Adding subtitle', file)

	local tmp_file
	if string.find(file, '%.txt$') then
		mp.msg.debug('Convert TXT to LRC')

		tmp_file = TMP_PREFIX .. '.lrc'
		mp.msg.debug('Using temporary file', tmp_file)

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

local function search(path, patterns)
	mp.msg.debug('Searching in', path)

	local num_files = 0
	for _, file in ipairs(utils.readdir(path, 'files') or {}) do
		num_files = num_files + 1
		for _, pattern in ipairs(patterns) do
			if string.find(file, pattern) then
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

mp.register_event('start-file', function()
	local path = mp.get_property('path')
	if not path then
		return
	end

	for _, track in ipairs(mp.get_property_native('track-list')) do
		if CODEC_BLACKLIST[track.codec] then
			return
		end
	end

	local dirname, filename = utils.split_path(path)

	local patterns = {}

	local function register(pattern)
		for _, ext in pairs(SUBTITLE_EXTENSIONS) do
			full_pattern = string.format('^%s%%.%s$', pattern, ext)
			mp.msg.debug('Use pattern', full_pattern)
			table.insert(patterns, full_pattern)
		end
	end

	register(str2pattern(filename))

	local without_ext = string.match(filename, '^(.+)%..+$')
	if without_ext then
		register(str2pattern(without_ext))
	end

	local season, episode = string.match(filename, '[sS]0*(%d+)[eE]0*(%d+)')
	if season and episode then
		register(string.format('.*[sS]0*%s[eE]0*%s.*', season, episode))
	end

	for _, subdir in ipairs(mp.get_property_native('sub-file-paths')) do
		search(utils.join_path(dirname, subdir), patterns)
	end
end)

mp.set_property_native('sub-auto', false)
