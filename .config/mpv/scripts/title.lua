-- Common stuff. We cannot use require since scripts folder is not among search paths.
function title()
	local artist = mp.get_property_native('metadata/by-key/Artist', nil)
	local title = mp.get_property_native('metadata/by-key/Title', nil) or
	              mp.get_property_native('media-title', nil)

	return (artist and title) and (artist .. ' - ' .. title) or title or mp.get_property_native('path', '')
end

-- Yank
function shesc(s)
	return "'" .. s:gsub("'", "'\"'\"'") .. "'"
end

mp.add_key_binding('y', 'yank-title', function()
	os.execute(('printf %%s %s | xclip -l 1 -selection clipboard'):format(shesc(title())))
	mp.osd_message('Yanked: ' .. name)
end, {repeatable=false})

-- Show
local show = false
local osd = mp.create_osd_overlay('ass-events')

function asscape(s)
	return s:gsub('{', '\\{')
end

function update_overlay()

	osd.data = ('{\\an7\\bord2\\fscx70\\fscy70}[%d/%d] %s'):format(
			mp.get_property('playlist-pos'),
			mp.get_property('playlist-count'),
			asscape(title())
	)
	osd:update()
end

function show_title()
	if show then
		update_overlay()
		mp.register_event('file-loaded', update_overlay)
	else
		osd:remove()
		mp.unregister_event(update_overlay)
	end
	show = not show
end

show_title()
mp.add_key_binding('T', 'show-title', show_title, {repeatable=false})
