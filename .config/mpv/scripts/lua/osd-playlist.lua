local osd = require('osd').new()
local utils = require('utils')
local title = require('title')

local font_scale = 0.65

local modal
local update
local old_visible = false
local props = {}
local forward

local playlist_changed = false

local function update_playlist()
	playlist_changed = false
	props['playlist'] = mp.get_property_native('playlist')
	update()
end

local playlist_timer
playlist_timer = mp.add_periodic_timer(0.1, function()
	if not playlist_changed then
		playlist_timer:kill()
		return
	end

	update_playlist()
end, true)

local function dirty_playlist()
	playlist_changed = true

	if modal:is_visible() and not playlist_timer:is_enabled() then
		playlist_timer:resume()
		update_playlist()
	end
end

local function compute_layout()
	local font_size = props['osd-font-size'] or 0
	local scaled_font_size = font_size * font_scale
	local margin_y = 2 * (props['osd-margin-y'] or 0)
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
	elseif name == 'playlist-count' then
		dirty_playlist()
		return
	end

	props[name] = value

	update()
end

function update()
	local visible = modal:is_visible()

	if old_visible ~= visible then
		old_visible = visible

		if visible then
			if playlist_changed then
				update_playlist()
			end
		else
			osd:remove()
		end
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
		local current = i == pos
		osd:N()
		osd:h()
		osd:put_cursor(current)
		osd:bold(current)
		osd:put(display)
		osd:bold(false)
	end

	if #playlist == 0 then
		osd:N()
		osd:h()
		osd:put_cursor(false)
		osd:italic(true)
		osd:put('(empty playlist)')
		osd:italic(false)
	end

	osd:update()
end
update = osd.update_wrap(update)

modal = require('modal').new(update)

mp.observe_property('osd-font-size', 'native', update_property)
mp.observe_property('osd-margin-y', 'native', update_property)
mp.observe_property('playlist-pos-1', 'native', update_property)
mp.observe_property('playlist-count', 'native', update_property)

utils.register_script_messages('osd-playlist', {
	visibility = modal.set_visibility,
	scroll_half_screen = scroll_half_screen,
})

mp.register_script_message('playlist-changed', function()
	dirty_playlist()
end)

mp.add_key_binding('Ctrl+d', function()
	scroll_half_screen('down')
end)
mp.add_key_binding('Ctrl+u', function()
	scroll_half_screen('up')
end)
