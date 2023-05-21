local props = {}

local function should_stop_screensaver()
	if props['pause'] then
		return false
	end

	if props['mute'] then
		return false
	end

	-- nil means unsupported.
	if props['focused'] == false then
		return false
	end

	for _, track in ipairs(props['track-list'] or {}) do
		if (
			track.selected and
			track.type == 'video' and
			not track.image and
			not track.albumart and
			(track['demux-fps'] or 0) > 1
		) then
			return true
		end
	end

	return false
end

local function update_property(name, value)
	props[name] = value

	local stop_screensaver = should_stop_screensaver()
	if props['stop-screensaver'] ~= stop_screensaver then
		mp.set_property_native('stop-screensaver', stop_screensaver)
	end
end

mp.observe_property('focused', 'native', update_property);
mp.observe_property('mute', 'native', update_property);
mp.observe_property('pause', 'native', update_property);
mp.observe_property('stop-screensaver', 'native', update_property);
mp.observe_property('track-list', 'native', update_property);
