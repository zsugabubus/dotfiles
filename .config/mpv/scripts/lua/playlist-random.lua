do
	local f = assert(io.open('/dev/random', 'rb'))

	local seed = 0
	for _ = 1, 4 do
		seed = 256 * seed + f:read(1):byte()
	end
	math.randomseed(seed)

	f:close()
end

mp.add_key_binding('r', 'playlist-random', function()
	local pos = math.random(0, mp.get_property_number('playlist-count') - 1)
	mp.commandv('script-message', 'playlist-pos', pos)
end)
