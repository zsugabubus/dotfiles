local utils = require 'mp.utils'
local COVERS = {'cover.jpg', 'cover.png'}

mp.observe_property('track-list', 'native', function()
	local path = mp.get_property('path')
	if not path then
		return
	end

	local dirname, _ = utils.split_path(path)

	local tracks = mp.get_property_native('track-list')
	local has_audio = false
	for _, track in ipairs(tracks) do
		if track.selected == 'yes' then
			if track.type == 'video' then
				return
			end

			has_audio = has_audio or (track.type == 'audio')
		end
	end

	if not has_audio then
		return
	end

	for _, covername in ipairs(COVERS) do
		local coverpath = dirname .. covername
		local coverinfo = utils.file_info(coverpath)
		if coverinfo and coverinfo.is_file then
			mp.commandv('video-add', coverpath)
			break
		end
	end
end)
