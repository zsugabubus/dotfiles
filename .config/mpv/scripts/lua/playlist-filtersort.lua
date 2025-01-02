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

local sort_options = {
	by = mp.get_opt('sort') or 'alpha',
}

local extension_blacklist = {
	exe = true,
	nfo = true,
	part = true,
	pdf = true,
	rar = true,
	sfv = true,
	srt = true,
	torrent = true,
	txt = true,
}

local function should_remove(s)
	return extension_blacklist[s:match('%.([^.]*)$')]
		or s:find('^sa?mple?[/.-]')
		or s:find('[/!.-]sample')
		or s:find('%.r[0-9]*$')
end

local function leading_number(n, s)
	return ('%s%08d'):format(s, n)
end

local function middle_number(n, c)
	return ('%08d%s'):format(n, c)
end

local sort_keys = {
	none = function() end,
	path = function(s)
		return s
	end,
	number = function(s)
		return s:gsub('([0-9]+)(.)', middle_number)
	end,
	file = function(s)
		return s:gsub('^.*/', '')
	end,
	alpha = function(s)
		return s:gsub('^.*/', '')
			:gsub('[.,;&_ ()[\135{}-]', '')
			:gsub('^([0-9]+)(.*)', leading_number)
			:gsub('([0-9]+)(.)', middle_number)
	end,
}

sort_keys.a = sort_keys.alpha
sort_keys.f = sort_keys.file
sort_keys.n = sort_keys.number
sort_keys.no = sort_keys.none
sort_keys.p = sort_keys.path

local function do_filtersort(sort_by)
	local start = mp.get_time()

	local playlist = mp.get_property_native('playlist')

	if #playlist <= 1 then
		return
	end

	local t = {}
	local sort_key = sort_keys[sort_by]
	local insert = table.insert

	for i = 1, #playlist do
		local entry = playlist[i]
		local s = entry.filename:lower()
		if should_remove(s) then
			mp.msg.info('Remove', entry.filename)
		else
			insert(t, {
				index = i,
				id = entry.id,
				key = sort_key(s),
			})
		end
	end

	table.sort(t, function(a, b)
		if a.key ~= b.key then
			return a.key < b.key
		end
		return a.index < b.index
	end)

	-- Keep "id" only.
	for _, x in ipairs(t) do
		x.key = nil
		x.index = nil
	end

	mp.set_property_native('playlist', t)
	mp.commandv('script-message', 'playlist-changed')

	local elapsed = mp.get_time() - start

	if sort_key('') then
		mp.msg.info(
			(
				'Filtered and sorted playlist by %s in %.3f seconds.'
				.. ' Disable sorting with --script-opts=sort=none or script-message sort none.'
			):format(sort_by, elapsed)
		)
	else
		mp.msg.info(
			('Filtered playlist in %.3f seconds. Sorting is disabled.'):format(
				elapsed
			)
		)
	end
end

local function validate_options()
	if sort_keys[sort_options.by] then
		return
	end

	local choices = {}
	for k in pairs(sort_keys) do
		table.insert(choices, k)
	end
	table.sort(choices)

	mp.msg.error(
		('Invalid sort %s, expected one of: %s.'):format(
			sort_options.by,
			table.concat(choices, ', ')
		)
	)
	sort_options.by = 'none'
end

local function update_options()
	validate_options()
end

do
	local old_playlist_count = 0

	mp.observe_property('playlist-count', 'number', function(_, playlist_count)
		if playlist_count > old_playlist_count then
			do_filtersort(sort_options.by)
		end
		old_playlist_count = playlist_count
	end)
end

mp.observe_property('options/script-opts', 'native', function(_, t)
	for name, value in pairs(t) do
		if name == 'sort' then
			mp.commandv('change-list', 'script-opts', 'set', 'sort-by=' .. value)
		end
	end
end)

mp.register_script_message('sort', function(sort_by)
	sort_options.by = sort_by or sort_options.by
	validate_options()
	do_filtersort(sort_options.by)
end)

require('mp.options').read_options(sort_options, 'sort', update_options)
validate_options()
