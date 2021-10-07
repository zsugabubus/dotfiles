local osd = mp.create_osd_overlay('ass-events')

local Osd = {}

Osd.NBSP = '\194\160'
Osd.RIGHT_ARROW = '\226\158\156'

function Osd:compute_font_scale(lines)
	local osd_font_size = mp.get_property_number('osd-font-size')
	local margin_y = 2 * mp.get_property_number('osd-margin-y')
	return ((osd.res_y - margin_y - osd_font_size) / osd_font_size) / lines
end

function Osd:append(...)
	for _, s in ipairs({...}) do
		self.data[#self.data + 1] = s
	end
end

Osd.__index = Osd

setmetatable(getmetatable(osd), Osd)

return osd
