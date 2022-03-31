mp.register_event('start-file', function()
	-- event.playlist_entry_id may differ if playlist item has been moved.
	local url = mp.get_property_native(
		('playlist/%d/filename')
			:format(mp.get_property_native('playlist-pos')))

	local bytes
	if url:find('://') then
		bytes = '500M'
	else
		bytes = '125M'
	end
	mp.set_property_native('demuxer-max-back-bytes', bytes)
end)

-- Ensure that we have at least as much bytes available forward than as
-- backward, so seeking back in a live stream does not accidentally stop
-- reading it.
mp.observe_property('demuxer-max-back-bytes', 'number', function(_, value)
	mp.set_property_number('demuxer-max-bytes', 2 * value)
end)
