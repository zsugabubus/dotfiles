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

local function deg2rad(angle)
	return angle / 180 * math.pi
end

local function xy_offset(x, y, angle, length)
	angle = deg2rad(angle)
	return
		x + math.cos(angle) * length,
		y - math.sin(angle) * length
end

function Osd:draw_triangle(x, y, a0, l0, a1, l1)
	self:draw_move(x, y)
	self:draw_line(xy_offset(x, y, a0, l0))
	self:draw_line(xy_offset(x, y, a1, l1))
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

return Osd
