mp.add_key_binding('R', 'reload-file', function()
	local path = mp.get_property('path')
	if not path then
		return
	end

	local current = mp.get_property_native('playlist-playing-pos')
	local last = mp.get_property('playlist-count')

	mp.commandv(
		'loadfile',
		path,
		'append',
		'start=' .. mp.get_property_number('time-pos')
	)
	mp.commandv('playlist-play-index', last)
	mp.commandv('playlist-move', last, current + 1)
	mp.commandv('playlist-remove', current)
end, { repeatable = false })
