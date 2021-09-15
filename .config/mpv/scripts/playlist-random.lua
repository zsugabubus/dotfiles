local f = assert(io.open('/dev/random', 'rb'))

local seed, s = 0, f:read(4)
for i = 1, s:len() do
	seed = 256 * seed + s:byte(i)
end
math.randomseed(seed)

io.close(f)

mp.add_key_binding('r', 'playlist-random', function()
	mp.set_property_number('playlist-pos', math.random(1, mp.get_property_number('playlist-count')))
end)
