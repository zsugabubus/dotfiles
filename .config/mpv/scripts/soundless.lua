-- For dumpass people who do not get why they cannot hear anything.
local osd = mp.create_osd_overlay('ass-events')

function icon(alpha, align, icon)
	return table.concat{
		'{\\an',
		align,
		'\\1a&H',
		alpha,
		'\\fscx250\\fscy250\\fnmpv-osd-symbols}',
		icon,
	}
end

function update()
	osd.data = {}
	osd.z = 100

	if mp.get_property_bool('pause') then
		table.insert(osd.data, icon('10', 4, '\238\128\130'))
	end

	if mp.get_property_bool('mute') then
		table.insert(osd.data, icon('50', 6, '\238\132\138'))
	end

	if 0 < #osd.data then
		osd.data = table.concat(osd.data, '\n')
		osd:update()
	else
		osd:remove()
	end
end

mp.observe_property('mute', nil, update)
mp.observe_property('pause', nil, update)
