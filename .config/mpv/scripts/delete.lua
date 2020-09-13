local utils = require 'mp.utils'
mp.add_key_binding('shift+DEL', 'delete-file', function()
	if not mp.get_property_bool('pause') and mp.get_property_number('time-pos') < 1 then
		return
	end

	local work_dir = mp.get_property_native('working-directory')
	local file_path = mp.get_property_native('path')
	local s = file_path:find(work_dir, 0, true)
	local path
	if s and s == 0 then
		path = file_path
	else
		path = utils.join_path(work_dir, file_path)
	end

	-- Is file?
	local f = io.open(path, 'r')
	if f ~= nil then
		io.close(f)
		local dir_name, _ = utils.split_path(path)
		if os.rename(path, dir_name .. '/.deleted') then
			mp.command('playlist_remove current')
			mp.osd_message('Deleted: ' .. file_path)
		else
			mp.osd_message('Failed to delete')
		end
	end
end, {repeatable=false})
