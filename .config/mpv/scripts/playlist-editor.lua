mp.add_key_binding('Ctrl+w', 'playlist-edit', function()
	local tmp = os.tmpname()
	local f = io.open(tmp, 'w')

	local pos = mp.get_property_native('playlist-pos-1')
	local playlist = mp.get_property_native('playlist')
	for i=1,#playlist do
		local entry = playlist[i]
		f:write(entry.filename, '\n')
	end
	f:close()

	local h = io.popen(('${VISUAL:-$TERMINAL -e $EDITOR} %s +%d >/dev/null && cat %s; rm %s >/dev/null'):format(tmp, pos, tmp, tmp))
	local first = true
	-- loadlist cannot be used because that uses URLs relative to the playlist
	-- location (/tmp).
	for entry in h:lines() do
		mp.commandv('loadfile', entry, first and 'replace' or 'append')
		first = false
	end
	h:close()
end, {repeatable=false})
