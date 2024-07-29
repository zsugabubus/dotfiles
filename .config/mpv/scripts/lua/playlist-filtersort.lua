--[[
- Override sort options temporarily.

  $ mpv --script-opts=sort=none ...
  $ mpv --script-opts=sort-by=none ...

- Change sort options from MPV console.

  set script-opts sort=none
  set script-opts sort-by=none

- Change sort options on key press.

  input.conf:
  s   change-list script-opts set sort-by=path
  S   change-list script-opts set sort-by=none

- Sort on demand.

  script-opts/sort.conf:
  by=none

  input.conf:
  s   script-message sort path
]]

local SORT_BY_CHOICES = {
	-- Do not sort.
	'none',
	-- Compare paths.
	'path',
	-- Compare filenames.
	'name',
	-- Similar to "name" but ignore special characters and use better number
	-- comparison.
	'alpha',
}
local sort_options = {
	by = mp.get_opt('sort') or 'alpha',
}

for _, k in ipairs(SORT_BY_CHOICES) do
	SORT_BY_CHOICES[k] = true
end

local function filter_playlist(playlist)
	local lower, match = string.lower, string.match

	for i = #playlist, 1, -1 do
		local entry = playlist[i]
		local s = lower(entry.filename)
		if
			match(s, '^sa?mple?[/.-]')
			or match(s, '[/!.-]sample')
			or match(s, '%.aria2$')
			or match(s, '%.exe$')
			or match(s, '%.torrent$')
			or match(s, '%.srt$')
			or match(s, '%.nfo$')
			or match(s, '%.part$')
			or match(s, '%.rar$')
			or match(s, '%.r[0-9]*$')
			or match(s, '%.sfv$')
			or match(s, '%.txt$')
			or match(s, '%.pdf$')
		then
			mp.msg.info('Remove', s)
			mp.commandv('playlist-remove', i - 1)
			table.remove(playlist, i)
		end
	end
end

local can_playlist_clear = true
local function sort_playlist(playlist, sort_by)
	if sort_by == 'none' then
		return
	end

	local order = {}
	local has_title = false

	-- Ignore leading numbers (mostly track numbers).
	local function sub_leading_number(n, s)
		return string.format('%s%08d', s, n)
	end

	-- Human numeric sort.
	local function sub_wide_number(n, c)
		return string.format('%08d%s', n, c)
	end

	for i = 1, #playlist do
		local entry = playlist[i]
		order[i] = i

		if sort_by == 'alpha' then
			entry.key = entry.filename
				:gsub('^.*/', '')
				:gsub('[.,;&_ ()[\135{}-]', '')
				:gsub('^([0-9]+)(.*)', sub_leading_number)
				:gsub('([0-9]+)(.)', sub_wide_number)
				:lower()
		elseif sort_by == 'name' then
			entry.key = entry.filename:gsub('^.*/', ''):lower()
		elseif sort_by == 'path' then
			entry.key = entry.filename
		end

		has_title = has_title or entry.title
	end

	table.sort(order, function(a, b)
		local x, y = playlist[a], playlist[b]
		if x.key ~= y.key then
			return x.key < y.key
		else
			return a < b
		end
	end)

	if can_playlist_clear and not has_title then
		-- TODO: Maybe we could use loadlist to preserve titles.
		mp.commandv('playlist-clear')
		-- entry.current cannot be trusted since current entry could have changed
		-- before playlist-clear.
		local current_entry_id = mp.get_property_native('playlist/0/id')
		for i = 1, #playlist do
			local entry = playlist[order[i]]
			if entry.id == current_entry_id then
				mp.commandv('playlist-move', 0, i)
			else
				mp.commandv('loadfile', entry.filename, 'append')
			end
		end
		return
	end

	-- Random magic number, very likely hardware dependent.
	local N = 20000

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
				mp.commandv('playlist-move', i - 1, (j + 1) - 1)
				mp.commandv('playlist-move', (j - 1) - 1, i - 1)
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

local old_playlist_count = 0
local old_sort_by
local function update_playlist(sort_by)
	local playlist_count = mp.get_property_native('playlist-count')

	-- MPV scripts are executed in parallel, so routines that modify playlist
	-- have to reside inside the same script to ensure sequential execution.
	--
	-- Because of this, it can be assumed that no other script touches playlist,
	-- so sorting (and filtering) have to be redone only when playlist-count
	-- increases.
	if old_playlist_count < playlist_count or old_sort_by ~= sort_by then
		local start = mp.get_time()

		local playlist = mp.get_property_native('playlist')
		playlist_count = #playlist

		if 1 < #playlist then
			filter_playlist(playlist)
			sort_playlist(playlist, sort_by)
			-- Issuing a random playlist-clear is unsafe since other scripts may
			-- modify playlist in parallel. As a heuristics, playlist-clear is only
			-- ever allowed to run once, when other scripts surely do not can about
			-- playlist. In practice it means "on startup" or after initial directory
			-- has been expanded.
			can_playlist_clear = false
		end

		local elapsed = mp.get_time() - start

		mp.msg.info(
			string.format(
				'Sorted by %s in %.3f seconds.%s',
				sort_by,
				elapsed,
				sort_by == 'none' and ''
					or ' Use --script-opts=sort=none to disable sorting.'
			)
		)
	end
	old_playlist_count = playlist_count
	old_sort_by = sort_by
end

local function validate_options()
	if not SORT_BY_CHOICES[sort_options.by] then
		sort_options.by = 'none'
		mp.msg.error(
			'--script-opts=sort-by= expects one of: '
				.. table.concat(SORT_BY_CHOICES, ', ')
		)
	end
end

local function update_options()
	validate_options()
	update_playlist(sort_options.by)
end

mp.observe_property('playlist-count', 'number', function()
	update_playlist(sort_options.by)
end)

mp.observe_property('options/script-opts', 'native', function(_, t)
	for name, value in pairs(t) do
		if name == 'sort' then
			mp.commandv('change-list', 'script-opts', 'set', 'sort-by=' .. value)
		end
	end
end)

mp.register_script_message('sort', function(sort_by)
	if not SORT_BY_CHOICES[sort_by] then
		mp.msg.error(
			'Usage: sort SORT_BY where SORT_BY is one of: '
				.. table.concat(SORT_BY_CHOICES, ', ')
		)
		return
	end

	update_playlist(sort_by)
end)

require('mp.options').read_options(sort_options, 'sort', update_options)
validate_options()
