mp.observe_property('playlist', nil, function()
	local playlist = mp.get_property_native('playlist')

	if #playlist <= 1 then
		return
	end

	for i=#playlist, 1, -1 do
		local entry = playlist[i]
		local s = entry.filename:lower()
		if s:match('^sample[/.-]') or
		   s:match('[/!.-]sample') or
		   s:match('%.aria2$') or
		   s:match('%.exe$') or
		   s:match('%.torrent$') or
		   s:match('%.srt$') or
		   s:match('%.nfo$') or
		   s:match('%.txt$') then
			mp.msg.info('removing playlist entry', s)
			mp.command(('playlist-remove %d'):format(i - 1))
		end
	end
end)
