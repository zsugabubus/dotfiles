-- https://aegi.vmoe.info/docs/3.1/ASS_Tags/
local M = {
	AUDIO_ICON = '\u{E106}',
	VIDEO_ICON = '\u{E108}',
	SUBTITLE_ICON = '\u{E107}',
}
M.__index = M

-- Rendering is never parallel and always starts with a cleared buffer so we
-- can use a shared scratch space to save some memory.
local buf = require('string.buffer').new()

local function esc_helper(s, nl)
	s = string.gsub(s, '\\', '\\\u{FEFF}')
	s = string.gsub(s, '{', '\\{')
	s = string.gsub(s, '\n', nl)
	return s
end

local function esc(s)
	return esc_helper(s, ' ')
end

local function update_size(self)
	self.height = self.ass.res_y
	self.width = self.ass.res_x
end

function M.new(opts)
	opts = opts or {}

	local ass = mp.create_osd_overlay('ass-events')
	ass.z = opts.z or 0

	local o = setmetatable({ ass = ass }, M)

	update_size(o)

	return o
end

function M:clear()
	self.ass.data = nil
	buf:reset()
end

function M:put(...)
	buf:put(...)
end

function M:putf(...)
	buf:putf(...)
end

function M:r()
	buf:put('{\\r}')
end

function M:h()
	buf:put('\\h')
end

function M:n()
	self:put('\n')
end

function M:N()
	buf:put('\\N')
end

function M:str(s)
	buf:put(esc(s))
end

function M:strnl(s)
	buf:put(esc_helper(s, '\\N'))
end

function M:wrap(on)
	buf:put(on and '{\\q1}' or '{\\q2}')
end

function M:an(x)
	buf:put('{\\an', x, '}')
end

function M:fs(x)
	buf:put('{\\fs', x, '}')
end

function M:fscy0(x)
	buf:put('{\\fscy0}')
end

function M:fsc(x)
	buf:put('{\\fscx', x, '\\fscy', x, '}')
end

function M:fn_monospace()
	buf:put('{\\fnmonospace}')
end

function M:fn_symbols()
	buf:put('{\\fnmpv-osd-symbols}')
end

function M:bold(on)
	buf:put(on and '{\\b1}' or '{\\b0}')
end

function M:italic(on)
	buf:put(on and '{\\i1}' or '{\\i0}')
end

function M:alpha(x)
	buf:putf('{\\alpha&H%02x}', x)
end

function M:a1(x)
	buf:putf('{\\1a&H%02x&}', x)
end

function M:c1(x)
	buf:putf('{\\1c&H%06x&}', x)
end

function M:c3(x)
	buf:putf('{\\3c&H%06x&}', x)
end

function M:bord(x)
	buf:put('{\\bord', x, '}')
end

function M:pos(x, y)
	buf:put('{\\pos(', x, ',', y, ')}')
end

function M:clip(x0, y0, x1, y1)
	buf:put('{\\clip(', x0, ',', y0, ',', x1, ',', y1, ')}')
end

function M:draw_begin()
	buf:put('{\\p1}')
end

function M:draw_end()
	buf:put('{\\p0}')
end

function M:draw_move(x, y)
	buf:put('m', x, ' ', y)
end

function M:draw_line(x, y)
	buf:put('l', x, ' ', y)
end

function M:draw_rect(x0, y0, x1, y1)
	self:draw_move(x0, y0)
	self:draw_line(x1, y0)
	self:draw_line(x1, y1)
	self:draw_line(x0, y1)
end

function M:draw_rect_wh(x, y, width, height)
	self:draw_rect(x, y, x + width, y + height)
end

function M:draw_rect_border(x0, y0, x1, y1, w)
	self:draw_move(x0, y0)
	self:draw_line(x1, y0)
	self:draw_line(x1, y1)
	self:draw_line(x0 + w, y1)
	self:draw_line(x0 + w, y1 - w)
	self:draw_line(x1 - w, y1 - w)
	self:draw_line(x1 - w, y0 + w)
	self:draw_line(x0 + w, y0 + w)
	self:draw_line(x0 + w, y1)
	self:draw_line(x0, y1)
end

local function deg2rad(deg)
	return deg / 180 * math.pi
end

local function xy_offset(x, y, deg, length)
	local rad = deg2rad(deg)
	return x + math.cos(rad) * length, y - math.sin(rad) * length
end

function M:draw_triangle(x, y, a0, l0, a1, l1)
	self:draw_move(x, y)
	self:draw_line(xy_offset(x, y, a0, l0))
	self:draw_line(xy_offset(x, y, a1, l1))
end

function M:put_cursor(visible)
	local RIGHT_ARROW_ICON = '\u{279C}'

	if visible then
		buf:put(RIGHT_ARROW_ICON)
	else
		self:alpha(0xff)
		buf:put(RIGHT_ARROW_ICON)
		self:alpha(0)
	end
	self:h()
end

function M:put_marker(active)
	buf:put(active and '●' or '○')
	self:h()
end

function M.observe_fsc_properties(fn)
	mp.observe_property('osd-font-size', 'native', fn)
	mp.observe_property('osd-margin-y', 'native', fn)
end

function M:compute_fsc(props, line_count, max_scale)
	local font_size = props['osd-font-size'] or 0
	local margin_y = 2 * (props['osd-margin-y'] or 0)
	local work_height = self.height - margin_y - font_size
	local font_scale = work_height / font_size / line_count
	return math.min(font_scale, max_scale or 1) * 100
end

function M:put_fsc(...)
	self:skip_message_line()
	self:wrap(false)
	self:fsc(self:compute_fsc(...))
end

function M:skip_message_line()
	self:h()
	self:n()
end

function M:update()
	if not self.ass.data then
		self.ass.data = buf:tostring()
	end

	if self.on_screen_data ~= self.ass.data then
		self.on_screen_data = self.ass.data
		self.ass:update()
	end
end

function M.update_wrap(update)
	local function update_wrapper()
		mp.unregister_idle(update_wrapper)
		update()
	end

	local function schedule_update()
		mp.register_idle(update_wrapper)
	end

	return schedule_update
end

function M:remove()
	if self.on_screen_data then
		self.on_screen_data = nil
		self.ass:remove()
	end
end

function M:set_res(w, h)
	self.ass.res_x, self.ass.res_y = w, h
	update_size(self)
end

M.esc = esc

return M
