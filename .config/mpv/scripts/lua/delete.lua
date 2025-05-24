local utils = require('mp.utils')

local function append_to_deleted_log(path)
	local f = assert(io.open('/tmp/mpv_deleted', 'a'))
	assert(f:write(path .. '\n'))
	assert(f:close())
end

local function move_to_deleted(path, deleted_ext)
	append_to_deleted_log(path)
	local dirname = utils.split_path(path)
	local deleted_path = utils.join_path(dirname, '.deleted' .. deleted_ext)
	local ok, err = os.rename(path, deleted_path)
	if not ok then
		mp.msg.error(err)
		return false
	end
	mp.msg.info(('Moved: %s -> %s'):format(path, deleted_path))
	return true
end

local function can_delete_extension(s)
	return s:match('^%.[a-z]+%.vtt$')
end

local function delete_related_paths(path)
	local dirname, thisfile = utils.split_path(path)
	local prefix = thisfile:match('(.+)%.[^.]+$')
	if not prefix then
		return
	end
	for _, file in ipairs(utils.readdir(dirname, 'files')) do
		if thisfile ~= file and file:find(prefix, 1, true) == 1 then
			local ext = file:sub(#prefix + 1)
			if can_delete_extension(ext) then
				move_to_deleted(utils.join_path(dirname, file), ext)
			end
		end
	end
end

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

	delete_related_paths(path)

	if move_to_deleted(path, '') then
		mp.osd_message('File deleted')
		mp.command('playlist_remove current')
	else
		mp.osd_message('Delete failed')
	end
end, { repeatable = false })
