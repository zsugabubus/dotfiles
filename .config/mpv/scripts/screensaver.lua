function update()
	mp.set_property_bool('stop-screensaver',
		not mp.get_property_bool('pause') and (function()
			local tracks = mp.get_property_native('track-list')
			for _, track in ipairs(tracks) do
				if 0 < (track['demux-fps'] or 0) then
					return true
				end
			end
			return false
		end)())
end

mp.observe_property('pause', nil, update);
mp.observe_property('file-loaded', nil, update);
