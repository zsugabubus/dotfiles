local osd = require('osd').new({ z = 10 })

local props = {}

local function osd_put_icon(align, text)
	osd:n()
	osd:an(align)
	osd:bord(2)
	osd:a1(40)
	osd:fsc(150)
	osd:fn_symbols()
	osd:put(text)
end

local function update()
	if not props['pause'] and not props['mute'] then
		osd:remove()
		return
	end

	osd:clear()

	if props['pause'] then
		osd_put_icon(4, '\u{E002}')
	end

	if props['mute'] then
		osd_put_icon(6, '\u{E10A}')
	end

	osd:update()
end

local function update_property(name, value)
	props[name] = value
	update()
end

mp.observe_property('mute', 'native', update_property)
mp.observe_property('pause', 'native', update_property)
