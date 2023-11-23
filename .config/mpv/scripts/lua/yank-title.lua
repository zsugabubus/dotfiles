local utils = require('utils')

local function yank()
	local artist = mp.get_property_native('metadata/by-key/Artist', nil)
	local title = (
		mp.get_property_native('metadata/by-key/Title', nil)
		or mp.get_property_native('media-title', nil)
	)
	local version = mp.get_property_native('metadata/by-key/Version', nil)
	local title = ('%s%s%s%s'):format(
		artist or '',
		artist and ' - ' or '',
		title,
		version and (' (%s)'):format(version) or ''
	)
	os.execute(
		('printf %%s %s | xclip -selection clipboard &'):format(utils.shesc(title))
	)
	mp.osd_message('Yanked: ' .. title)
end

utils.register_script_messages('yank-title', {
	yank = yank,
})
