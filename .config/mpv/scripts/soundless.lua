-- For dumpass people who do not get why they cannot hear anything.
local osd = mp.create_osd_overlay("ass-events")

function update(_, _)
	osd.data = "{\\an4\\1a&H40\\fscx200\\fscy200\\fnmpv-osd-symbols}"
	if mp.get_property_bool('pause') then
		osd.data = osd.data .. "\238\128\130"
	elseif mp.get_property_bool('mute') then
		osd.data = osd.data .. "\238\132\138"
	else
		osd:remove()
		return
	end
	osd:update()
end

mp.observe_property('mute', 'bool', update)
mp.observe_property('pause', 'bool', update)
