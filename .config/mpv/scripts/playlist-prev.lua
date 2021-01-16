local jumplist = {}

mp.observe_property('playlist-pos', 'number', function(_, pos)
	if pos and 0 <= pos and pos ~= jumplist[#jumplist] then
		if 5 <= #jumplist then
			for i=1,#jumplist-1 do
				jumplist[i] = jumplist[i + 1]
			end
			jumplist[#jumplist] = nil
		end
		jumplist[#jumplist + 1] = pos
	end
end)

mp.add_key_binding('Ctrl+o', 'playlist-prev', function()
	if 2 <= #jumplist then
		-- Pop current.
		jumplist[#jumplist] = nil
		local prev = jumplist[#jumplist]
		mp.set_property_number('playlist-pos', prev)
	end
end)
