local osd = mp.create_osd_overlay("ass-events")
osd.data = "{\\an4\\1a&H40\\fscx200\\fscy200\\fnmpv-osd-symbols}\238\132\138"

mp.observe_property('mute', 'bool', function(_, mute)
	if mute then
		osd:update()
	else
		osd:remove()
	end
end)
