mp.add_key_binding('R', 'reload-file', function()
	local path = mp.get_property('path')
	if path ~= nil then
		mp.commandv(
			'loadfile', path,
			'replace',
			'start=' .. mp.get_property_number('time-pos')
		)
	end
end, {repeatable=false})
