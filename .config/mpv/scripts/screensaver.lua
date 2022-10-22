local HAS_MOTION = {
	h264 = true,
	mjpeg = false
}

function update()
	mp.set_property_bool('stop-screensaver',
		not mp.get_property_bool('pause') and
		not mp.get_property_bool('mute') and
		(function()
			local ret = HAS_MOTION[mp.get_property_native('video-format')]
			if ret ~= nil then
				return ret
			end

			local tracks = mp.get_property_native('track-list')
			for _, track in ipairs(tracks) do
				if track.selected and 0 < (track['demux-fps'] or 0) then
					return true
				end
			end
			return false
		end)())
end

mp.observe_property('pause', nil, update);
mp.observe_property('mute', nil, update);
mp.observe_property('file-loaded', nil, update);
mp.observe_property('current-tracks', nil, update);
