local options = require('mp.options')
local osd = require('osd').new()

local visible = false

local function _update()
	mp.unregister_idle(_update)

	local metadata = mp.get_property_native('metadata', {})
	local lines = #metadata
	local font_scale = math.min(
		.5,
		osd:compute_font_scale(lines)
	)

	osd.data = {
		('{\\an9}\\h\n{\\fscx%d\\fscy%d\\an9\\q0\\a1\\bord2}'):format(
			font_scale * 100, font_scale * 100),
	}

	local o = {}
	for k, v in pairs(metadata) do
		if k ~= '' then
			o[#o + 1] = {k, v}
		end
	end
	table.sort(o, function(x, y) return x[1] < y[1] end)

	local any = false
	for _, x in pairs(o) do
		osd:append('{\\b1}', osd.ass_escape(x[1]), '{\\b0}: ', osd.ass_escape(x[2]), '\\N')
		any = true
	end

	if not any then
		osd:append('(no metadata)')
	end

	osd:update()
end
function update()
	mp.unregister_idle(_update)
	mp.register_idle(_update)
end

mp.add_key_binding('M', 'toggle', function()
	mp.unobserve_property(update)

	visible = not visible
	if visible then
		mp.observe_property('metadata', nil, update)
	else
		osd:remove()
	end
end)
