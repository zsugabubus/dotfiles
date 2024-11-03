local function xclip(data)
	mp.command_native({
		name = 'subprocess',
		detach = true,
		playback_only = false,
		stdin_data = data,
		args = {
			'xclip',
			'-selection',
			'clipboard',
		},
	})
end

mp.register_script_message('yank-title', function()
	local artist = mp.get_property_native('metadata/by-key/Artist', nil)
	local title = (
		mp.get_property_native('metadata/by-key/Title', nil)
		or mp.get_property_native('media-title', nil)
	)
	local version = mp.get_property_native('metadata/by-key/Version', nil)

	local s = table.concat({
		artist or '',
		artist and ' - ' or '',
		title,
		version and (' (%s)'):format(version) or '',
	})

	xclip(s)
	mp.osd_message('Yanked: ' .. s)
end)
