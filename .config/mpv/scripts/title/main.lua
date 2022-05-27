local osd = require('osd').new()
local title = require('title')
local visible = false

osd.z = 10

function _update()
	mp.unregister_idle(_update)

	local style = '\\c&H00ffFF\\bord2\\fscx70\\fscy70}'
	osd.data = {}

	osd:append('\n{\\an2', style)

	osd:append(title.get_current(osd))

	for _, track in ipairs(mp.get_property_native('track-list')) do
		if not track.selected then
			goto continue
		end
		if track.type == 'video' then
			local pars = mp.get_property_native('video-params')
			if pars then
				osd:append('\n{\\an3', style,
					('%s%dx%d'):format(track.albumart and '[P] ' or '', pars.w, pars.h))
			end
			break
		elseif track.type == 'audio' then
			local pars = mp.get_property_native('audio-params')
			if pars then
				osd:append('\n{\\an3', style,
					('%s %s'):format(track.codec, pars['hr-channels']))
			end
		end
		::continue::
	end

	local duration = mp.get_property('duration')
	if duration then
		osd:append('\n{\\an3', style, (' %02d:%02d'):format(duration / 60, duration % 60))
	end

	osd:append('\n{\\an1', style,
		mp.get_property('playlist-pos'),
		'/',
		mp.get_property('playlist-count'))

	osd:update()
end
function update()
	mp.unregister_idle(_update)
	mp.register_idle(_update)
end

mp.add_key_binding('T', 'show-title', function()
	mp.unobserve_property(update)
	mp.unregister_event(update)

	visible = not visible
	if visible then
		mp.register_event('file-loaded', update)
		mp.observe_property('playlist-count', nil, update)
		mp.observe_property('playlist-pos', nil, update)
		mp.observe_property('video-params', nil, update)
		mp.observe_property('audio-params', nil, update)
	else
		title.flush_cache()
		osd:remove()
	end
end, {repeatable=false})

--- Yank
local function shesc(s)
	return ("'%s'"):format(s:gsub("'", "'\"'\"'"))
end

mp.add_key_binding('y', 'yank-title', function()
	local artist = mp.get_property_native('metadata/by-key/Artist', nil)
	local title = mp.get_property_native('metadata/by-key/Title', nil) or
	              mp.get_property_native('media-title', nil)
	local version = mp.get_property_native('metadata/by-key/Version', nil)
	local title = ('%s%s%s%s'):format(artist or '', artist and ' - ' or '', title, version and (' (%s)'):format(version) or '')
	os.execute(('printf %%s %s | xclip -l 1 -selection clipboard &'):format(shesc(title)))
	mp.osd_message('Yanked: ' .. title)
end, {repeatable=false})
