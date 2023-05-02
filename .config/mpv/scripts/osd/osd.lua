-- https://aegi.vmoe.info/docs/3.1/ASS_Tags/
local M = {
	__newindex = function(self, key)
		error(key)
	end,
}
M.__index = M

M.AUDIO = '\u{E106}'
M.VIDEO = '\u{E108}'
M.SUBTITLE = '\u{E107}'

local function update_size(self)
	self.height = self.ass.res_y
	self.width = self.ass.res_x
end

function M.new(opts)
	opts = opts or {}

	local o = {
		ass = mp.create_osd_overlay('ass-events'),
		buf = require 'string.buffer'.new(),
	}

	o.ass.z = opts.z or 0
	update_size(o)

	return setmetatable(o, M)
end

function M:reset()
	self.ass.data = nil
	return self.buf:reset()
end

function M:put(...)
	return self.buf:put(...)
end

function M:putf(...)
	return self.buf:putf(...)
end

function M:put_cursor(active)
	local RIGHT_ARROW = '\u{279C}'

	return self:put(
		active and '' or '{\\alpha&HFF}',
		RIGHT_ARROW,
		'{\\alpha&H00}\\h',
		active and '{\\b1}' or '{\\b0}'
	)
end

function M:put_rcursor(active)
	if active then
		return self:put('{\\b0}')
	end
end

function M:put_marker(active)
	return self:put(active and '●' or '○', '\\h')
end

function M.observe_fsc_properties(fn)
	mp.observe_property('osd-font-size', 'native', fn)
	mp.observe_property('osd-margin-y', 'native', fn)
end

function M:put_fsc(props, line_count, max_scale)
	local font_size = props['osd-font-size'] or 0
	local margin_y = 2 * (props['osd-margin-y'] or 0)
	local work_height = self.height - margin_y - font_size
	local font_scale = work_height / font_size / line_count
	font_scale = math.min(font_scale, max_scale or 1)

	-- Insert blank line to skip message line.
	self:put('\\h\n')
	-- Disable line wrapping so line_count is exact.
	self:putf(
		'{\\q2\\fscx%d\\fscy%d}',
		font_scale * 100,
		font_scale * 100
	)
end

function M:draw_begin()
	return self:put('{\\p1}')
end

function M:draw_end()
	return self:put('{\\p0}')
end

function M:draw_move(x, y)
	return self:put('m ', x, ' ', y, ' ')
end

function M:draw_line(x, y)
	return self:put('l ', x, ' ', y, ' ')
end

function M:draw_rect(x0, y0, x1, y1)
	self:draw_move(x0, y0)
	self:draw_line(x1, y0)
	self:draw_line(x1, y1)
	return self:draw_line(x0, y1)
end

function M:draw_rect_wh(x, y, width, height)
	return self:draw_rect(x, y, x + width, y + height)
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

function M:draw_triangle(x, y, a0, l0, a1, l1)
	self:draw_move(x, y)
	self:draw_line(xy_offset(x, y, a0, l0))
	return self:draw_line(xy_offset(x, y, a1, l1))
end

function M:update()
	if not self.ass.data then
		self.ass.data = self.buf:tostring()
	end
	return self.ass:update()
end

function M.update_wrap(update)
	local function update_wrapper()
		mp.unregister_idle(update_wrapper)
		return update()
	end

	local function schedule_update()
		return mp.register_idle(update_wrapper)
	end

	return schedule_update
end

function M:remove()
	return self.ass:remove()
end

function M:set_res(w, h)
	self.ass.res_x, self.ass.res_y = w, h
	return update_size(self)
end

function M.ass_escape(s)
	return s
		-- ASS' escape handling is WTF: RS cannot be escaped with RS so we trick it
		-- by using ZWJ.
		:gsub('\\', '\\\u{FEFF}')
		:gsub('{', '\\{')
		:gsub('\n', '\\N')
end

function M.ass_escape_nl(s)
	return M.ass_escape(string.gsub(s, '\n', ' '))
end

return M
