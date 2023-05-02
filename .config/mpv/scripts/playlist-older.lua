local MAX_HISTORY = 10

local history = {}

mp.observe_property('playlist-pos', 'native', function(_, current)
	if
		current >= 0 and
		current ~= history[#history]
	then
		if #history >= MAX_HISTORY then
			table.remove(history, 1)
		end
		table.insert(history, current)
	end
end)

mp.add_key_binding('Ctrl+o', 'playlist-older', function()
	if #history >= 2 then
		-- Pop current.
		history[#history] = nil
		local prev = history[#history]
		mp.commandv('script-message', 'playlist-pos', prev)
	end
end)
