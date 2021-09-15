-- For dumpass people who do not get why they cannot hear anything.
local osd = mp.create_osd_overlay('ass-events')

function get_icon(align, icon)
	return "{\\an" .. align .. "\\1a&H40\\fscx200\\fscy200\\fnmpv-osd-symbols}" .. icon
end

function update(_, _)
	osd.data = ""

	if mp.get_property_bool('pause') then
		osd.data = osd.data ..  get_icon(4, "\238\128\130") .. "\n"
	end

	if mp.get_property_bool('mute') then
		osd.data = osd.data ..  get_icon(6, "\238\132\138") .. "\n"
	end

	if osd.data == "" then
		osd:remove()
	else
		osd:update()
	end
end

mp.observe_property('mute', 'bool', update)
mp.observe_property('pause', 'bool', update)
