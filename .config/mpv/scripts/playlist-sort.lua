ignore = 0
mp.observe_property('playlist', nil, function()
	if 0 < ignore then
		ignore = ignore - 1
		return
	end

	local playlist = mp.get_property_native('playlist')
	for i=1,#playlist do
		playlist[i].pos = i
	end

	table.sort(playlist, function(x, y)
		local xs = x.filename
		local ys = y.filename
		local xss = xs:gsub('[0-9._ ()/-]', ''):lower()
		local yss = ys:gsub('[0-9._ ()/-]', ''):lower()
		if xss ~= yss then
			return xss < yss
		elseif xs ~= ys then
			return xs < ys
		else
			return x.pos < y.pos
		end
	end)

	local indexes = {}
	for i=1,#playlist do
		indexes[playlist[i].pos] = i
	end

	mp.msg.info('Sorting...')
	for pos=1,#indexes do
		local self = indexes[pos]
		local up = 0
		for i=1,pos-1 do
			 up = up + ((self < indexes[i]) and 1 or 0)
		end

		if 0 ~= up then
			ignore = ignore + 1
			mp.commandv('playlist-move', pos - 1, pos - up - 1)
		end
	end
	mp.msg.info('Fininshed')
end)
