local function update()
	mp.unregister_event(update)

	local url = mp.get_property_native('path')

	local bytes
	if url:find('://') then
		bytes = '512M'
	else
		bytes = '125M'
	end
	mp.set_property_native('demuxer-max-back-bytes', bytes)
end
mp.register_event('start-file', update)

-- Ensure that we have at least as much bytes available forward than as
-- backward, so seeking back in a live stream does not accidentally stop
-- reading it.
mp.observe_property('demuxer-max-back-bytes', 'native', function(_, value)
	mp.set_property_number('demuxer-max-bytes', 2 * value)
end)
