local COVERS = {'cover.jpg', 'cover.png'}

local utils = require 'mp.utils'

local skip_dir

mp.observe_property('track-list', 'native', function(_, tracks)
	local path = mp.get_property('path')
	if not path then
		return
	end

	local dirname, _ = utils.split_path(path)
	if dirname == skip_dir then
		return
	end

	local has_audio = false

	for _, track in ipairs(tracks) do
		if track.type == 'video' then
			return
		end

		if track.type == 'audio' then
			has_audio = true
		end
	end

	if not has_audio then
		return
	end

	for _, name in ipairs(COVERS) do
		local cover_path = utils.join_path(dirname, name)
		local stat = utils.file_info(cover_path)
		if stat and stat.is_file then
			mp.commandv('video-add', cover_path)
			return
		end
	end

	skip_dir = dirname
end)
