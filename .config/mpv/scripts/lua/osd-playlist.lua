local osd = require('osd').new()
local utils = require('utils')
local title = require('title')

local font_scale = 0.65

local visible = false
local props = {}
local forward
local hide_timeout

local old_visible

local update

local function set_visible(action)
	local temporary = false

	if action == 'show' or action == 'peek' then
		temporary = action == 'peek' and (not visible or hide_timeout:is_enabled())
		visible = true
	elseif action == 'hide' then
		visible = false
	elseif action == 'toggle' or action == 'blink' then
		temporary = action == 'blink'
		visible = not visible
	end

	hide_timeout:kill()
	if temporary then
		hide_timeout:resume()
	end

	update()
end

local function compute_layout()
	local font_size = props['osd-font-size'] or 0
	local scaled_font_size = font_size * font_scale
	local margin_y = 2 * props['osd-margin-y']
	local playlist_height = osd.height - margin_y - font_size

	-- Subtract one line so it is visually a bit more pleasant.
	local lines = math.floor(playlist_height / scaled_font_size) - 1
	local y = font_size + (playlist_height - lines * scaled_font_size) / 2

	return lines, y
end

local function scroll_half_screen(action)
	local lines = compute_layout()
	local pos = props['playlist-pos-1']
	pos = pos + (action == 'up' and -1 or 1) * math.floor((lines + 1) / 2)
	mp.commandv('script-message', 'playlist-pos', pos)
end

local function update_property(name, value)
	if name == 'playlist-pos-1' then
		local old = props['playlist-pos-1'] or -1
		if old ~= value then
			forward = old <= value
		end
	end

	props[name] = value

	update()
end

function update()
	if old_visible ~= visible then
		old_visible = visible

		mp.unobserve_property(update_property)
		mp.observe_property('osd-font-size', 'native', update_property)
		mp.observe_property('osd-margin-y', 'native', update_property)
		mp.observe_property('playlist-pos-1', 'native', update_property)

		if visible then
			mp.observe_property('playlist', 'native', update_property)
		else
			osd:remove()
		end

		return
	end

	if not visible then
		return
	end

	local pos = props['playlist-pos-1'] or 0
	local playlist = props['playlist'] or {}
	local lines, y = compute_layout()

	osd:clear()
	osd:wrap(false)
	osd:pos(0, y)
	osd:fsc(font_scale * 100)

	local top, bottom
	top = math.max(1, pos - math.floor(lines * (forward and 0.2 or 0.8)))
	bottom = math.min(top + lines, #playlist)
	top = math.max(1, bottom - lines)

	for i = top, bottom do
		local entry = playlist[i]
		local display = title.from_playlist_entry(entry)
		osd:N()
		osd:h()
		osd:put_cursor(entry.current)
		osd:bold(entry.current)
		osd:put(display)
		osd:bold(false)
	end

	osd:update()
end
update = osd.update_wrap(update)

hide_timeout = mp.add_timeout(
	mp.get_property_number('osd-duration') / 1000,
	function()
		set_visible('hide')
	end,
	true
)

utils.register_script_messages('osd-playlist', {
	visibility = set_visible,
	scroll_half_screen = scroll_half_screen,
})

mp.add_key_binding('Ctrl+d', function()
	scroll_half_screen('down')
end)
mp.add_key_binding('Ctrl+u', function()
	scroll_half_screen('up')
end)

update()
