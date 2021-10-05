local osd = mp.create_osd_overlay('ass-events')
local visible = false

osd.z = 10

function ass_escape(s)
	local x = s:gsub('[\\{]', '\\%0')
	return x
end

function osd_append(...)
	for _, s in ipairs({...}) do
		osd.data[#osd.data + 1] = s
	end
end

function update()
	local style = '\\c&H00ffFF\\bord2\\fscx70\\fscy70}'
	osd.data = {}

	osd_append('\n{\\an2', style)
	local artist = mp.get_property_native('metadata/by-key/Artist', nil)
	local title = mp.get_property_native('metadata/by-key/Title', nil) or
	              mp.get_property_native('media-title', nil)

	if artist and title then
		local version = mp.get_property_native('metadata/by-key/Version', nil)

		osd_append(ass_escape(artist), ' - ', '{\\b1}', ass_escape(title), '{\\b0}')

		if version then
			osd_append(' (', ass_escape(version), ')')
		end
	elseif title then
		osd_append(ass_escape(title))
	else
		osd_append(ass_escape(mp.get_property_native('path', '')))
	end

	for _, track in ipairs(mp.get_property_native('track-list')) do
		if not track.selected then
			goto continue
		end
		if track.type == 'video' then
			local pars = mp.get_property_native('video-params')
			osd_append('\n{\\an3', style,
				('%s%dx%d'):format(track.albumart and '[P] ' or '', pars.w, pars.h))
			break
		elseif track.type == 'audio' then
			local apars = mp.get_property_native('audio-params')
			osd_append('\n{\\an3', style,
				('%s %s'):format(track.codec, apars['hr-channels']))
		end
		::continue::
	end

	local duration = mp.get_property('duration')
	if duration then
		osd_append('\n{\\an3', style, (' %02d:%02d'):format(duration / 60, duration % 60))
	end

	osd_append('\n{\\an1', style,
		mp.get_property('playlist-pos'),
		'/',
		mp.get_property('playlist-count'))

	osd.data = table.concat(osd.data)
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
