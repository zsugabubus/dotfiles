function shesc(s)
	return "'" .. s:gsub("'", "\"'\"") .. "'"
end

mp.add_key_binding('y', 'yank-name', function()
	local artist = mp.get_property_native("metadata/by-key/Artist", nil)
	local title = mp.get_property_native("metadata/by-key/Title", nil) or
	              mp.get_property_native("media-title", nil)

	local name = (artist and title) and (artist .. " - " .. title) or title or mp.get_property_native("path", "")

	os.execute(("printf %%s %s | xclip -l 1 -selection clipboard"):format(shesc(name)))
	mp.osd_message('Yanked: ' .. name)
end, {repeatable=false})
