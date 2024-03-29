local utils = require('mp.utils')

mp.add_key_binding(nil, 'delete-file', function()
	local path = mp.get_property_native('path')
	if not path then
		return
	end

	-- Perform safety checks after 'path' has been get to avoid race conditions.
	if
		not mp.get_property_bool('pause')
		and mp.get_property_number('time-pos', 0) < 1
	then
		mp.msg.error(
			'Safety check blocked deleting file that has just started to play'
		)
		mp.msg.info(
			'To delete the file pause playback or try again a few moments later'
		)
		mp.osd_message('Delete blocked')
		return
	end

	local dirname, _ = utils.split_path(path)

	local log_path = utils.join_path(dirname, '.deleted.log')
	local f, err = io.open(log_path, 'a')
	if not f then
		mp.msg.error(err)
		mp.osd_message('Delete failed')
		return
	end
	f:write(path .. '\n')
	f:close()

	local new_path = utils.join_path(dirname, '.deleted')
	local ok, err = os.rename(path, new_path)
	if ok then
		mp.msg.info(('Moved: %s -> %s'):format(path, new_path))
		mp.osd_message('File deleted')
		mp.command('playlist_remove current')
	else
		mp.msg.error(err)
		mp.osd_message('Delete failed')
	end
end, { repeatable = false })
