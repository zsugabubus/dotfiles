local function seek(pos, whence, wrap)
	local cur = mp.get_property_number('playlist-pos')
	local count = mp.get_property_number('playlist-count')

	if whence == 'SEEK_CUR' then
		pos = cur + pos
	end

	if wrap and count > 0 then
		pos = ((pos % count) + count) % count
	else
		pos = math.min(math.max(0, pos), count - 1)
	end

	-- Avoid unloading current file.
	if pos == cur then
		return
	end

	mp.set_property_number('playlist-pos', pos)
end

mp.register_script_message('playlist-pos', function(pos)
	seek(pos, 'SEEK_SET', false)
end)

mp.add_key_binding('p', 'playlist-prev', function()
	seek(-1, 'SEEK_CUR', true)
end)

mp.add_key_binding('n', 'playlist-next', function()
	seek(1, 'SEEK_CUR', true)
end)
