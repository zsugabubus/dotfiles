local osd = require('osd').new({ z = 10 })

local props = {}

local function osd_put_icon(align, alpha, text)
	osd:n()
	osd:an(align)
	osd:a1(alpha)
	osd:fsc(200)
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
		osd_put_icon(4, 20, '\u{E002}')
	end

	if props['mute'] then
		osd_put_icon(6, 50, '\u{E10A}')
	end

	osd:update()
end
update = osd.update_wrap(update)

local update_timeout = mp.add_timeout(0.05, update, true)

local function update_property(name, value)
	if name == 'pause' and value then
		-- Workaround for not updating screen after pause.
		update_timeout:resume()
	end

	props[name] = value

	update()
end

mp.observe_property('mute', 'native', update_property)
mp.observe_property('pause', 'native', update_property)
