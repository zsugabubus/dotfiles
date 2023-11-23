local osd = require('osd').new({ z = 10 })

local props = {}
local update_timeout

local function osd_put_icon(align, alpha, text)
	osd:put(
		'\n{\\an',
		align,
		'\\1a&H',
		alpha,
		'\\fscx200\\fscy200\\fnmpv-osd-symbols}',
		text
	)
end

local function update()
	if not props['pause'] and not props['mute'] then
		osd:remove()
		return
	end

	osd:reset()

	if props['pause'] then
		osd_put_icon(4, 20, '\u{E002}')
	end

	if props['mute'] then
		osd_put_icon(6, 50, '\u{E10A}')
	end

	osd:update()
end
update = osd.update_wrap(update)

update_timeout = mp.add_timeout(0.05, update)
update_timeout:kill()

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
