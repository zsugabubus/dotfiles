local function update()
	mp.unregister_event(update)

	local url = mp.get_property_native('path')
	if not url then
		return
	end

	local bytes
	if url:find('://') then
		bytes = '512M'
	else
		bytes = '125M'
	end
	mp.set_property_native('demuxer-max-back-bytes', bytes)
end
mp.register_event('start-file', update)

-- Ensure that we have at least as much bytes available forward than as
-- backward, so seeking back in a live stream does not accidentally stop
-- reading it.
mp.observe_property('demuxer-max-back-bytes', 'native', function(_, value)
	mp.set_property_number('demuxer-max-bytes', 2 * value)
end)

mp.add_key_binding(nil, 'select-cache', function()
	local MiB = 1024 * 1024
	local GiB = 1024 * MiB

	local choices = {
		{ 'n: none', false },
		{ 'a: 64M', 64 * MiB },
		{ 'b: 512M', 512 * MiB },
		{ 'c: 1G', 1 * GiB },
		{ 'd: 2G', 2 * GiB },
		{ 'e: 4G', 4 * GiB },
	}

	local items = {}
	local default_item = 1
	local current = mp.get_property_native('cache', 'native')
		and mp.get_property_native('demuxer-max-back-bytes')

	for i, choice in pairs(choices) do
		table.insert(items, choice[1])
		if choice[2] == current then
			default_item = i
		end
	end

	require('mp.input').get({
		prompt = 'Cache',
		items = items,
		default_text = '^',
		default_item = default_item,
		select_one = true,
		submit = function(i)
			local value = choices[i][2]
			if not value then
				mp.commandv('osd-msg-bar', 'set', 'cache', 'no')
			else
				mp.commandv('set', 'cache', 'yes')
				mp.commandv('osd-msg-bar', 'set', 'demuxer-max-back-bytes', value)
			end
		end,
	})
end)
