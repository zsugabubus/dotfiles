local SORT_OPTS = {no=true, filename=true}

local sort = mp.get_opt('sort')
if sort and not SORT_OPTS[sort] then
	local s = {"If --script-opts=sort=X is given, it must be one of"}
	for k in pairs(SORT_OPTS) do
		s[#s + 1] = #s <= 1 and ': ' or ', '
		s[#s + 1] = '`'
		s[#s + 1] = k
		s[#s + 1] = "'"
	end
	s[#s + 1] = ", got `"
	s[#s + 1] = sort
	s[#s + 1] = "'"
	mp.msg.error(table.concat(s))
end

local function do_filter()
	local playlist = mp.get_property_native('playlist')

	if #playlist <= 1 then
		return
	end

	for i=#playlist, 1, -1 do
		local entry = playlist[i]
		local s = entry.filename:lower()
		if s:match('^sa?mple?[/.-]') or
			 s:match('[/!.-]sample') or
			 s:match('%.aria2$') or
			 s:match('%.exe$') or
			 s:match('%.torrent$') or
			 s:match('%.srt$') or
			 s:match('%.nfo$') or
			 s:match('%.part$') or
			 s:match('%.txt$') then
			mp.msg.info('Removing', s)
			mp.commandv('playlist-remove', i - 1)
		end
	end
end

local function playlist_swap(playlist, i1, i2)
	if i1 < i2 then
		mp.commandv('playlist-move', (i1)     - 1, (i2 + 1) - 1)
		mp.commandv('playlist-move', (i2 - 1) - 1, (i1)     - 1)
	elseif i1 > i2 then
		mp.commandv('playlist-move', (i1)     - 1, (i2)     - 1)
		mp.commandv('playlist-move', (i2 + 1) - 1, (i1 + 1) - 1)
	else
		return false
	end

	playlist[i2], playlist[i1] = playlist[i1], playlist[i2]
	return true
end

local function do_sort()
	if sort == 'no' then
		return
	end

	local playlist = mp.get_property_native('playlist')

	local order = {}

	for i=1, #playlist do
		local entry = playlist[i]
		order[i] = i

		if sort == 'filename' then
			entry.string = entry.filename
		else
			entry.string = entry.filename
				:gsub('^.*/', '')
				:gsub('[.,;&_ ()[\135{}-]', '')
				:gsub('^[0-9]+', '')
				:lower() ..
				entry.filename:gsub('[^0-9]', '')
		end
	end

	table.sort(order, function(a, b)
		local x, y = playlist[a], playlist[b]
		if x.string ~= y.string then
			return x.string < y.string
		else
			return a < b
		end
	end)

	for i=1, #playlist do
		playlist[order[i]].new_pos = i
	end

	for i=1, #playlist do
		while playlist_swap(playlist, i, playlist[i].new_pos) do
		end
	end
end

local old = 0
function update()
	local current = mp.get_property_number('playlist-count')
	if old < current then
		local start = mp.get_time()

		-- Since different mpv scripts are executed on different (OS) threads it is
		-- possible that a different playlist item will be deleted at a given index
		-- because sort thread has moved it. TOCTOU, simply.
		--
		-- To avoid this, every script that modifies playlist must be executed
		-- sequentially.
		do_filter()
		do_sort()

		local elapsed = mp.get_time() - start

		mp.msg.info('Completed in', elapsed, 'seconds')
	end
	old = current
end

mp.observe_property('playlist-count', nil, update)
