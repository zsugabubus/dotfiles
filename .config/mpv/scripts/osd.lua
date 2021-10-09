local osd = mp.create_osd_overlay('ass-events')

local Osd = {}

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

function Osd.ass_escape(s)
	local x = s:gsub('\n', ' '):gsub('[\\{]', '\\%0')
	return x
end

function Osd.ass_escape_lines(s)
	return s:gsub('([^\n]*)\n', function(m) return Osd.ass_escape(m) .. '\\N' end)
end

Osd.__index = Osd

setmetatable(getmetatable(osd), Osd)

return osd
