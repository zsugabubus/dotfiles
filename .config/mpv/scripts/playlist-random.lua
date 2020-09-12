mp.add_key_binding('R', 'playlist-random', function()
	mp.set_property_number('playlist-pos', math.random(1, mp.get_property_number('playlist-count')))
end)
