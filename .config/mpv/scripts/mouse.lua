--[[ local opts = {
	max_speed = 3
}

local change_speed = false
function speedway()
	if change_speed then
		return
	end
	local pos = mp.get_property_native('mouse-pos')
	local w = mp.get_osd_size()
	local speed = 1 + opts.max_speed * pos.x / w
	mp.set_property_number('speed', speed)
end ]]

function get_tile()
	local pos = mp.get_property_native('mouse-pos')
	local w, h = mp.get_osd_size()
	-- 0 1 2
	-- 3 4 5
	-- 6 7 8
	return
		math.floor(pos.y * 3 / h) * 3 +
		math.floor(pos.x * 3 / w)
end

function scroll(e)
	local scroll = e.key_name:find('WHEEL_') ~= nil

	if e.event ~= 'down' then
		--[[ if change_speed then
			change_speed = false
			mp.set_property_number('speed', 1)
		end ]]
		return
	end

	local tile = get_tile()
	local up = e.key_name:find('UP')
	local small = not e.key_name:find('Shift+')
	if tile == 0 or tile == 3 then
		if scroll then
			mp.commandv(up and 'frame-step' or 'frame-back-step')
		end
	elseif tile == 1 then
		if scroll then
			mp.commandv(up and 'playlist-next' or 'playlist-prev')
		end
		mp.commandv('script-message-to', 'osd_playlist', 'peek')
	elseif tile == 2 or tile == 5 then
		if scroll then
			mp.commandv('osd-msg-bar', 'add', 'volume', (up and 1 or -2) * (small and 1 or 3))
		else
			mp.commandv('osd-msg-bar', 'set', 'volume', 100)
		end
	elseif scroll and tile == 6 then
		mp.commandv('seek', (up and 1 or -2) * (small and 1 or 3), 'exact')
	else
		if scroll then
			mp.commandv('osd-msg-bar', 'seek', (up and 2 or -1) * (small and 5 or 15), 'exact')
		end
	end
end

for _, mod in ipairs({'', 'Shift+'}) do
	for _, key in ipairs({'WHEEL_UP', 'WHEEL_DOWN', 'MBTN_MID'}) do
		mp.add_forced_key_binding(mod .. key, scroll, {complex=true})
	end
end
