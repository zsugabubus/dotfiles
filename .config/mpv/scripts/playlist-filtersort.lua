local SORT_OPTS = {
	none=true,
	alpha=true,
	strict=true,
}
-- Random magic number, very likely hardware dependent. See explanation below.
local N = 20000

local sort = mp.get_opt('sort') or 'alpha'
if not SORT_OPTS[sort] then
	local s = {"--script-opts=sort=X must be one of"}
	for k in pairs(SORT_OPTS) do
		s[#s + 1] = #s <= 1 and ': ' or ', '
		s[#s + 1] = '`'
		s[#s + 1] = k
		s[#s + 1] = "'"
	end
	s[#s + 1] = ", got `"
	s[#s + 1] = sort
	s[#s + 1] = "'."
	mp.msg.error(table.concat(s))
	return
end

if sort ~= 'none' then
	mp.msg.info('Use --script-opts=sort=none to disable.')
end

local function filter_playlist(playlist)
	local match = string.match
	for i = #playlist, 1, -1 do
		local entry = playlist[i]
		local s = entry.filename:lower()
		if
			match(s, '^sa?mple?[/.-]') or
			match(s, '[/!.-]sample') or
			match(s, '%.aria2$') or
			match(s, '%.exe$') or
			match(s, '%.torrent$') or
			match(s, '%.srt$') or
			match(s, '%.nfo$') or
			match(s, '%.part$') or
			match(s, '%.rar$') or
			match(s, '%.r[0-9]*$') or
			match(s, '%.sfv$') or
			match(s, '%.txt$') or
			false
		then
			mp.msg.info('Remove', s)
			mp.commandv('playlist-remove', i - 1)
			table.remove(playlist, i)
		end
	end
end

local function sort_playlist(playlist)
	if sort == 'none' then
		return
	end

	local order = {}

	for i = 1, #playlist do
		local entry = playlist[i]
		order[i] = i

		if sort == 'alpha' then
			entry.string = entry.filename
				:gsub('^.*/', '')
				:gsub('[.,;&_ ()[\135{}-]', '')
				:gsub('^[0-9]+', '')
				:lower() ..
				entry.filename:gsub('[^0-9]', '')
		elseif sort == 'strict' then
			entry.string = entry.filename
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

	-- Swapping entries requires two playlist-move commands per entry, however
	-- for <N entries the second playlist-move has such high (communication)
	-- overhead[0] that it worths doing somewhat more computation
	-- instead.
	-- For >=N entries quadric blowup hits in so we fall back to the linear
	-- version.
	--
	-- [0]: We have to wait for the result. And using async is not an option
	-- since they can be executed in any order.
	if N <= #playlist then
		for i = 1, #playlist do
			playlist[order[i]].new_pos = i
		end

		for i = 1, #playlist do
			while true do
				local j = playlist[i].new_pos
				if i == j then
					break
				end
				mp.commandv('playlist-move', (i)     - 1, (j + 1) - 1)
				mp.commandv('playlist-move', (j - 1) - 1, (i)     - 1)
				playlist[j], playlist[i] = playlist[i], playlist[j]
			end
		end
	else
		for i = 1, #playlist do
			playlist[i].index = i - 1
			playlist[i].next = playlist[i + 1]
			playlist[order[i]].next_ord = playlist[order[i + 1] or 0]
		end

		local cur = playlist[1]
		local cur_ord = playlist[order[1]]
		while cur do
			if cur ~= cur_ord then
				local index = cur.index

				-- cur -> [next ->]... cur_ord
				mp.commandv('playlist-move', cur_ord.index, index)

				cur_ord.index = index

				local last
				local entry = cur
				while entry ~= cur_ord do
					index = index + 1
					entry.index = index
					last = entry
					entry = entry.next
				end
				last.next = cur_ord.next

				cur_ord.next = cur
				-- cur_ord -> cur -> [next ->]... last -> cur_ord.next
			end

			cur_ord, cur = cur_ord.next_ord, cur_ord.next
		end
	end
end

local old = 0
function update(_, playlist_count)
	-- MPV scripts are executed in parallel, so routines that modify playlist
	-- have to reside inside the same script to ensure sequential execution.
	--
	-- Because of this, it can be assumed that no other script touches playlist,
	-- so sorting (and filtering) have to be redone only when playlist-count
	-- increases.
	if old < playlist_count then
		local start = mp.get_time()

		local playlist = mp.get_property_native('playlist')

		if 1 < #playlist then
			filter_playlist(playlist)
			sort_playlist(playlist)
		end

		local elapsed = mp.get_time() - start

		mp.msg.info('Completed in', elapsed, 'seconds')
		playlist_count = #playlist
	end
	old = playlist_count
end

mp.observe_property('playlist-count', 'number', update)
