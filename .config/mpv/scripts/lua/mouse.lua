local function get_tile()
	local pos = mp.get_property_native('mouse-pos')
	local w, h = mp.get_osd_size()
	-- 0 1 2
	-- 3 4 5
	-- 6 7 8
	return math.floor(pos.y * 3 / h) * 3 + math.floor(pos.x * 3 / w)
end

local function handle(e)
	-- "down" on X, "press" on Wayland.
	if e.event == 'up' then
		return
	end

	local tile = get_tile()
	local up = string.find(e.key_name, 'UP')
	local scroll = string.find(e.key_name, 'WHEEL_') ~= nil

	if tile == 0 or tile == 3 then
		if scroll then
			mp.commandv(up and 'frame-step' or 'frame-back-step')
		end
	elseif tile == 1 then
		if scroll then
			mp.commandv('script-message', up and 'playlist-next' or 'playlist-prev')
		end
		mp.commandv('script-message', 'osd-playlist', 'visibility', 'peek')
	elseif tile == 2 or tile == 5 then
		if scroll then
			mp.commandv('osd-msg-bar', 'add', 'volume', up and 1 or -2)
		else
			mp.commandv('osd-msg-bar', 'set', 'volume', 100)
		end
	elseif tile == 6 then
		if scroll then
			mp.commandv('script-message', 'osd-bar', 'seek', up and 1 or -1, 'exact')
		end
	else
		if scroll then
			mp.commandv('script-message', 'osd-bar', 'seek', up and 5 or -5, 'exact')
		end
	end
end

for _, key in ipairs({ 'WHEEL_UP', 'WHEEL_DOWN', 'MBTN_MID' }) do
	mp.add_forced_key_binding(key, handle, { complex = true })
end
