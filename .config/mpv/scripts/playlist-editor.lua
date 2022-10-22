mp.add_key_binding('Ctrl+w', 'playlist-edit', function()
	local tmp = os.tmpname()
	local f = io.open(tmp, 'w')
	if f == nil then
		return
	end

	local pos = mp.get_property_native('playlist-pos-1')
	local playlist = mp.get_property_native('playlist')
	for i = 1, #playlist do
		local entry = playlist[i]
		f:write(entry.filename, '\n')
	end

	f:close()

	local visual = os.getenv('VISUAL')
	local p = mp.command_native({
		name='subprocess',
		playback_only=false,
		args=
			visual
				and {
					visual,
					'--',
					tmp,
				}
				or {
					-- Some terminals (e.g. Alacritty) has fucked signal handling so we
					-- must start it from shell to unblock SIGCHLD.
					'/bin/sh',
					'-c',
					("%s -e /bin/sh -c '%s +%d -- %s || rm -f -- %s'"):format(
						os.getenv('TERMINAL') or 'xterm',
						os.getenv('EDITOR') or 'vim',
						pos,
						tmp,
						tmp),
				}
	})

	local f = io.open(tmp, 'r')
	if f ~= nil then
		local first = true
		-- loadlist cannot be used because that uses URLs relative to the playlist
		-- location (/tmp).
		for entry in f:lines() do
			mp.commandv('loadfile', entry, first and 'replace' or 'append')
			first = false
		end

		f:close()
		os.remove(tmp)
	end
end, {repeatable=false})
