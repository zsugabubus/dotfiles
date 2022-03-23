local Osd = {}

function Osd:__index(k)
	return getmetatable(self)[k]
end

Osd.RIGHT_ARROW = '\226\158\156'

function Osd.new()
	local osd = mp.create_osd_overlay('ass-events')
	setmetatable(Osd, getmetatable(osd))
	setmetatable(osd, Osd)
	return osd
end

function Osd:compute_font_scale(lines)
	local osd_font_size = mp.get_property_number('osd-font-size')
	local margin_y = 2 * mp.get_property_number('osd-margin-y')
	return ((self.res_y - margin_y - osd_font_size) / osd_font_size) / lines
end

function Osd:append(...)
	for _, s in ipairs({...}) do
		self.data[#self.data + 1] = s
	end
end

function Osd:draw_begin()
	self:append('{\\p1}')
end

function Osd:draw_end()
	self:append('{\\p0}')
end

function Osd:draw_move(x, y)
	self:append('m ', x, ' ', y, ' ')
end

function Osd:draw_line(x, y)
	self:append('l ', x, ' ', y, ' ')
end

function Osd:draw_rect(x0, y0, x1, y1)
	self:draw_move(x0, y0)
	self:draw_line(x1, y0)
	self:draw_line(x1, y1)
	self:draw_line(x0, y1)
end

function Osd:draw_rect_wh(x, y, width, height)
	self:draw_rect(x, y, x + width, y + height)
end

function Osd:update()
	self.data = table.concat(self.data)
	return getmetatable(Osd).update(self)
end

function Osd.ass_escape(s)
	local x = s
		-- ASS' escape handling is WTF: RS cannot be escaped with RS so we trick it
		-- by using ZWJ.
		:gsub('\\', '\\\239\187\191')
		:gsub('{', '\\{')
		:gsub('\n', '\\N')
	return x
end

function Osd.ass_escape_lines(s)
	return s:gsub('([^\n]*)\n', function(m)
		return Osd.ass_escape(m) .. '\\N'
	end)
end

return Osd
