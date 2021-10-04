local osd = mp.create_osd_overlay('ass-events')
local visible = false

osd.z = 10

function asscape(s)
	return s:gsub('\\', '\\\\'):gsub('{', '\\{')
end

function title()
	local artist = mp.get_property_native('metadata/by-key/Artist', nil)
	local title = mp.get_property_native('metadata/by-key/Title', nil) or
	              mp.get_property_native('media-title', nil)
	local version = mp.get_property_native('metadata/by-key/Version', nil)
	return (artist and title) and (artist .. ' - ' .. title .. (version and ' (' .. version .. ')' or '')) or title or mp.get_property_native('path', '')
end

function update()
	local duration = mp.get_property('duration') or 0
	osd.data = ('{\\an2\\c&H00ffFF\\bord2\\fscx70\\fscy70}[%d/%d] %s'):format(
		mp.get_property('playlist-pos'),
		mp.get_property('playlist-count'),
		asscape(title())) ..
		(0 < duration * 1 and (' (%02d:%02d)'):format(duration / 60, duration % 60) or '')
	osd:update()
end

mp.add_key_binding('T', 'show-title', function()
	visible = not visible
	if visible then
		mp.register_event('file-loaded', update)
		update()
	else
		mp.unregister_event(update)
		osd:remove()
	end
end, {repeatable=false})
