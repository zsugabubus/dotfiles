local osd = require('osd').new()
local utils = require('utils')
local title = require('title')

local visibility = 'auto'
local visible = false
local hide_timeout
local props = {
	speed = 1,
	['playlist-pos'] = -1,
	['playlist-count'] = 0,
	['mouse-pos'] = { x = 0, y = 0 },
}
local base_sub_margin_y = mp.get_property_native('sub-margin-y')
local mouse_time
local chapter_pos

local old_visibility
local old_visible
local old_mouse_prog_hit
local old_mouse_y = -1
local old_title

local fsx_cache = {}
local text_osd = mp.create_osd_overlay('ass-events')
text_osd.hidden = true
text_osd.compute_bounds = true

local update

local function measure_text(size)
	size = math.floor(size)

	local width = fsx_cache[size]
	if not width then
		text_osd.res_y = size * 2
		text_osd.res_x = size * 2
		text_osd.data = string.format('{\\q2\\fs%d\\fnmonospace}00', size)
		local bounds = text_osd:update()
		text_osd:remove()

		width = bounds.x1 / 2
		fsx_cache[size] = width
	end

	return width
end

local function set_sub_margin_y(value)
	if props['sub-margin-y'] ~= value then
		props['sub-margin-y'] = value
		-- set_property() is handled only after window resize, commandv() applied
		-- immediately (when subtitle changes).
		mp.commandv('set', 'sub-margin-y', value)
	end
end

local function set_visibility(action)
	hide_timeout:kill()

	if action == 'toggle' then
		visibility = visibility == 'auto' and 'show' or 'auto'
	elseif action == 'blink' then
		if visibility == 'auto' then
			visible = true
			hide_timeout:resume()
		end
	else
		visibility = action
	end

	if visibility == 'hide' then
		visible = false
	elseif visibility == 'show' then
		visible = true
	end

	update()
end

local function update_property(name, value)
	if name == 'metadata' or name == 'media-title' or name == 'playlist-pos' then
		old_title = nil
	elseif name == 'osd-dimensions' then
		osd:set_res(value.w, value.h)
		update()
		return
	end

	local old = props[name]
	props[name] = value

	if old and value then
		if
			-- VO may not support 'focused' so exlicitly check for false.
			props['focused'] == false
			and not props['paused']
			and not props['mouse-pos']['hover']
		then
			if name ~= 'time-pos' and name ~= 'duration' then
				return
			end

			if math.floor(old) == math.floor(value) then
				return
			end
		elseif name == 'time-pos' then
			-- Only when change is visible on progress bar.
			local x = osd.width / (props['duration'] or 1)
			if math.floor(x * old) == math.floor(x * value) then
				return
			end
		elseif name == 'duration' then
			-- Only whole number changes.
			if math.floor(old) == math.floor(value) then
				return
			end
		elseif name == 'demuxer-cache-state' then
			-- "seekable-ranges" does not worth frequent updates.
			if
				math.floor(old['cache-duration']) == math.floor(value['cache-duration'])
			then
				return
			end
		end
	end

	update()
end

local function handle_mouse_live_seek(event)
	mp.commandv(
		'no-osd',
		'seek',
		mouse_time,
		props['duration'] < 10 * 60 and 'absolute+exact' or 'absolute+keyframes'
	)
end

local function handle_mouse_seek(event)
	if event.event ~= 'up' then
		mp.commandv('no-osd', 'seek', mouse_time, 'absolute+exact')
		mp.add_forced_key_binding(
			'MOUSE_MOVE',
			'osd-bar/MOUSE_MOVE',
			handle_mouse_live_seek
		)
	else
		mp.remove_key_binding('osd-bar/MOUSE_MOVE')
	end
	mp.flush_keybindings()
end

local function handle_mouse_live_seek_to_chapter(event)
	if chapter_pos then
		mp.commandv('set', 'chapter', tostring(chapter_pos.id))
	end
end

local function handle_mouse_seek_to_chapter(event)
	if event.event ~= 'up' then
		if not chapter_pos then
			mp.commandv('no-osd', 'seek', '0', 'absolute+exact')
			return
		end

		mp.commandv('set', 'chapter', tostring(chapter_pos.id))
		mp.add_forced_key_binding(
			'MOUSE_MOVE',
			'osd-bar/MOUSE_MOVE',
			handle_mouse_live_seek_to_chapter
		)
	else
		mp.remove_key_binding('osd-bar/MOUSE_MOVE')
	end
	mp.flush_keybindings()
end

local function osd_put_human_time(time)
	local neg = time < 0
	time = math.abs(time)
	local hour = math.floor(time / 3600)
	local min = math.floor(time / 60 % 60)
	local sec = math.floor(time % 60)
	osd:putf('%s%02d:%02d:%02d', neg and '-' or '', hour, min, sec)
end

local function osd_put_human_duration(duration)
	local min = math.floor(duration / 60)
	local sec = math.floor(duration % 60)
	if min > 0 then
		osd:putf('%dm%02ds', min, sec)
	else
		osd:putf('%2ds', sec)
	end
end

local COMPLEX = { complex = true }

function update()
	local main_fs = math.max(math.floor(math.min(osd.width, osd.height) / 23), 30)

	local top_fs = main_fs * 0.625

	local side_width = 11 * measure_text(main_fs)
	local box_width = osd.width
	local top_small = box_width < 4 * side_width
	local prog_small = box_width < 3 * side_width
	local box_height = top_fs + (top_small and top_fs or 0) + main_fs
	local box_x0 = 0
	local box_x1 = box_x0 + box_width
	local box_y1 = osd.height
	local box_y0 = box_y1 - box_height

	local main_width = box_width - (prog_small and 0 or 2 * side_width)
	local main_height = main_fs
	local main_x0 = box_x0 + (prog_small and 0 or side_width)
	local main_x1 = main_x0 + main_width
	local main_y0 = box_y1 - main_height
	local main_y1 = main_y0 + main_height
	local main_yc = (main_y0 + main_y1) / 2

	local percent = (props['time-pos'] or 0) / (props['duration'] or 1)
	local prog_margin = 2
	local prog_x0 = main_x0 + prog_margin
	local prog_y0 = main_y0 + prog_margin
	local prog_width = main_width - 2 * prog_margin
	local prog_height = main_height - 2 * prog_margin
	local prog_fill_width = prog_width * percent
	local prog_pos = prog_x0 + prog_fill_width

	local duration = props['duration'] or 0

	local mouse = props['mouse-pos']
	local mouse_hit = mouse.hover
		and (
			(box_x0 <= mouse.x and mouse.x <= box_x1)
			and (box_y0 <= mouse.y and mouse.y <= box_y1)
		)
	local mouse_main_hit = mouse_hit
		and (main_y0 <= mouse.y and mouse.y < main_y0 + box_height)
	local mouse_percent = (mouse.x - prog_x0) / prog_width
	local mouse_prog_hit = mouse_main_hit
		and (0 <= mouse_percent and mouse_percent < 1)
	mouse_time = duration * mouse_percent

	if visibility == 'auto' then
		if old_visibility ~= visibility then
			-- Must be below `active_region` to make it work as expected.
			old_mouse_y = math.huge
		end

		if mouse_hit then
			visible = true
			hide_timeout:kill()
		elseif old_mouse_y ~= mouse.y then
			local active_region = osd.height * 2 / 3
			-- Entering the bottom third blinks bar.
			if mouse.y >= active_region then
				visible = true
				hide_timeout:kill()
				hide_timeout:resume()
			-- Leaving the bottom third immediately hides bar.
			elseif old_mouse_y >= active_region then
				visible = false
				hide_timeout:kill()
			end
			old_mouse_y = mouse.y
		end
	end

	if old_visibility ~= visibility or old_visible ~= visible then
		old_visibility = visibility
		old_visible = visible

		mp.unobserve_property(update_property)

		if visibility == 'auto' or visible then
			mp.observe_property('mouse-pos', 'native', update_property)
			mp.observe_property('osd-dimensions', 'native', update_property)
		end

		if visible then
			mp.observe_property('ab-loop-a', 'native', update_property)
			mp.observe_property('ab-loop-b', 'native', update_property)
			mp.observe_property('chapter-list', 'native', update_property)
			mp.observe_property('demuxer-cache-state', 'native', update_property)
			mp.observe_property('demuxer-via-network', 'native', update_property)
			mp.observe_property('duration', 'native', update_property)
			mp.observe_property('focused', 'native', update_property)
			mp.observe_property('media-title', nil, update_property)
			mp.observe_property('metadata', nil, update_property)
			mp.observe_property('pause', nil, update_property) -- To show exact values on pause.
			mp.observe_property('playlist-count', 'native', update_property)
			mp.observe_property('playlist-pos', 'native', update_property)
			mp.observe_property('speed', 'native', update_property)
			mp.observe_property('time-pos', 'native', update_property)
		end

		if not visible then
			hide_timeout:kill()
			osd:remove()
			set_sub_margin_y(base_sub_margin_y)
			mouse_prog_hit = false
		end
	end

	if old_mouse_prog_hit ~= mouse_prog_hit then
		old_mouse_prog_hit = mouse_prog_hit

		if mouse_prog_hit then
			props['window-dragging'] = mp.get_property_native('window-dragging')
			mp.set_property_native('window-dragging', false)
			mp.add_forced_key_binding(
				'MBTN_LEFT',
				'osd-bar/MBTN_LEFT',
				handle_mouse_seek,
				COMPLEX
			)
			mp.add_forced_key_binding(
				'MBTN_MID',
				'osd-bar/MBTN_MID',
				handle_mouse_seek,
				COMPLEX
			)
			mp.add_forced_key_binding(
				'MBTN_RIGHT',
				'osd-bar/MBTN_RIGHT',
				handle_mouse_seek_to_chapter,
				COMPLEX
			)
		else
			mp.set_property_native('window-dragging', props['window-dragging'])
			mp.remove_key_binding('osd-bar/MBTN_LEFT')
			mp.remove_key_binding('osd-bar/MBTN_MID')
			mp.remove_key_binding('osd-bar/MBTN_RIGHT')
			mp.remove_key_binding('osd-bar/MOUSE_MOVE')
		end
		mp.flush_keybindings()
	end

	if not visible then
		return
	end

	local function osd_clip_main(prog)
		osd:put(
			'{\\clip(',
			prog == 'right' and prog_pos or main_x0,
			',',
			main_y0,
			',',
			prog == 'left' and prog_pos or main_x1,
			',',
			main_y1,
			')}'
		)
	end

	local function time2x(time)
		return duration > 0 and time / duration * prog_width or 0
	end

	osd:reset()

	-- Bar background.
	do
		osd:put('{\\r\\pos(', box_x0, ',', box_y0, ')}')
		osd:put('{\\bord0\\1a&H2E&\\1c&H000000&}')
		osd:draw_begin()
		osd:draw_rect_wh(0, 0, box_width, box_height)
		osd:draw_end()
		osd:put('\n')
	end

	-- Progress bar.
	do
		osd:put('{\\r\\pos(', main_x0, ',', main_y0, ')}')
		osd:put('{\\bord0\\1a&HEE&\\1c&HFFFFFF&}')
		osd:draw_begin()
		osd:draw_rect_wh(0, 0, math.ceil(main_width), math.ceil(main_height))
		osd:draw_end()
		osd:put('\n')
	end

	-- Filled progress bar.
	do
		osd:put('{\\r\\pos(', prog_x0, ',', prog_y0, ')}')
		osd:put('{\\bord0\\1a&H10&\\1c&HFFFFFF&}')
		osd:draw_begin()
		osd:draw_rect_wh(0, 0, prog_fill_width, prog_height)
		osd:draw_end()
		osd:put('\n')
	end

	local cache = props['demuxer-cache-state']

	-- Cache ranges.
	do
		local seekable_ranges = cache and cache['seekable-ranges']
		if seekable_ranges and #seekable_ranges > 0 then
			local line_margin = math.ceil(main_height / 2 - main_fs / 20)
			local x, y = main_x0 + prog_margin, main_y0

			local function draw()
				for _, range in ipairs(seekable_ranges) do
					osd:draw_rect(
						math.floor(time2x(range.start)),
						line_margin,
						math.floor(time2x(range['end'])),
						main_height - line_margin
					)
				end
			end

			-- Part over filled part.
			osd:put('{\\r\\pos(', x, ',', y, ')\\bord0\\1a&H10&\\1c&H000000&}')
			osd_clip_main('left')
			osd:draw_begin()
			draw()
			osd:draw_end()
			osd:put('\n')

			-- Part over unfilled part.
			osd:put('{\\r\\pos(', x, ',', y, ')\\bord0\\1a&H10&\\1c&HFFFFFF&}')
			osd_clip_main('right')
			osd:draw_begin()
			draw()
			osd:draw_end()
			osd:put('\n')
		end
	end

	if not (prog_small and mouse_prog_hit) then
		local fs = main_fs * (prog_small and 0.8 or 1)
		-- Left block.
		osd:put(
			'{\\r\\pos(',
			box_x0 + (prog_small and 0 or side_width / 2),
			',',
			main_yc,
			')}'
		)
		osd:put(
			'{\\bord2\\fs',
			fs,
			'\\fnmonospace\\an',
			prog_small and '4}\\h' or '5}'
		)
		osd_put_human_time(props['time-pos'] or 0)
		osd:put('\n')

		-- Right block.
		osd:put(
			'{\\r\\pos(',
			box_x1 - (prog_small and 0 or side_width / 2),
			',',
			main_yc,
			')}'
		)
		osd:put(
			'{\\bord2\\fs',
			fs,
			'\\fnmonospace\\an',
			prog_small and '6}' or '5}'
		)
		if mouse_prog_hit then
			osd_put_human_time(-(duration - mouse_time))
		elseif
			mouse_main_hit == (props['demuxer-via-network'] or props['speed'] ~= 1)
		then
			osd_put_human_time(duration)
		else
			local time_remaininig = (props['duration'] or 0)
				- (props['time-pos'] or 0)
			local playtime_remaininig = time_remaininig / props['speed']
			osd_put_human_time(-playtime_remaininig)
		end
		osd:put(prog_small and '\\h' or '', '\n')
	end

	-- Top left block.
	do
		osd:put(
			'{\\r\\pos(',
			box_x0 + side_width / 2,
			',',
			math.floor(box_y0 + top_fs / 2),
			')}'
		)
		osd:put('{\\bord1\\fs', top_fs, '\\fnmonospace\\an5}')
		osd:put(props['playlist-pos'], '/', props['playlist-count'])
		osd:put('\n')
	end

	-- Top right block.
	if cache then
		osd:put(
			'{\\r\\pos(',
			box_x1 - side_width / 2,
			',',
			math.floor(box_y0 + top_fs / 2),
			')}'
		)
		osd:put('{\\bord1\\fs', top_fs, '\\fnmonospace\\an5}')
		osd:put('Cache: ')
		osd_put_human_duration(cache['cache-duration'] or 0)
		osd:put('/', math.floor((cache['total-bytes'] or 0) / 1000 / 1000), 'M')
		osd:put('\n')
	end

	-- Chapter markers.
	do
		chapter_pos = nil

		local chapters = props['chapter-list']
		if chapters and #chapters > 0 then
			local tri_height = main_fs / 8
			local tri_side = tri_height / math.sin(45 / 180 * math.pi)

			osd:put(
				'{\\r\\pos(',
				main_x0 + prog_margin,
				',',
				main_y0,
				')\\bord1\\1a&H10&\\1c&HFFFFFF&}'
			)
			osd:draw_begin()
			for i, chapter in ipairs(chapters) do
				chapter.id = i - 1
				local x = time2x(chapter.time)
				osd:draw_triangle(x, tri_height, 90 + 45, tri_side, 90 - 45, tri_side)
				osd:draw_triangle(
					x,
					main_height - tri_height,
					-90 + 45,
					tri_side,
					-90 - 45,
					tri_side
				)
			end
			osd:draw_end()
			osd:put('\n')

			local chapter_at = mouse_prog_hit and mouse_time
				or (props['time-pos'] or 0)

			for _, chapter in ipairs(chapters) do
				if
					chapter.time <= chapter_at
					and (not chapter_pos or chapter_pos.time <= chapter.time)
				then
					chapter_pos = chapter
				end
			end
		end
	end

	do
		local function draw_ab(name, rot, color)
			local time = props[name]
			if time == 'no' or not time then
				return
			end

			local tri_height = main_fs / 5
			local tri_side = tri_height / math.sin(45 / 180 * math.pi)

			osd:put(
				'{\\r\\pos(',
				main_x0 + prog_margin,
				',',
				main_y0,
				')\\bord1\\1a&H10&\\1c&H',
				color,
				'&}'
			)
			osd:draw_begin()
			local x = time2x(math.min(time, duration))
			osd:draw_triangle(x, tri_height, 90, tri_height, rot, tri_side)
			osd:draw_triangle(
				x,
				main_height - tri_height,
				-90,
				tri_height,
				-rot,
				tri_side
			)
			osd:draw_end()
			osd:put('\n')
		end

		draw_ab('ab-loop-a', 90 + 45, '0000FF')
		draw_ab('ab-loop-b', 90 - 45, '00FF00')
	end

	-- Mouse position.
	if mouse_prog_hit then
		local mouse_align = mouse.x < osd.width / 2 and 4 or 6

		-- A second, 2-width white outline so it is legible over cached ranges that
		-- is also black.
		osd:put('{\\r\\1c&HFFFFFF&\\fs', main_fs, '\\fnmonospace}')
		osd:put('{\\pos(', mouse.x, ',', main_yc, ')}')
		osd_clip_main('left')
		osd:put('{\\bord4\\an', mouse_align, '}')
		osd:put('{\\3c&HFFFFFF&}\\h')
		osd_put_human_time(mouse_time)
		osd:put('\\h\n')

		osd:put('{\\r\\1c&HFFFFFF&\\fs', main_fs, '\\fnmonospace}')
		osd:put('{\\pos(', mouse.x, ',', main_yc, ')}')
		osd_clip_main()
		osd:put('{\\bord2\\an', mouse_align, '}')
		osd:put('{\\3c&H000000&}\\h')
		osd_put_human_time(mouse_time)
		osd:put('\\h\n')
	end

	-- Top center block.
	do
		local mouse_chapter = mouse_prog_hit and chapter_pos
		local x0 = top_small and box_x0
			or (mouse_chapter and prog_x0 + time2x(mouse_chapter.time) or main_x0)
		local y0 = box_y0 + (top_small and top_fs or 0)
		local align = x0 < osd.width / 2 and 4 or 6
		osd:put('{\\r\\pos(', x0, ',', y0 + top_fs / 2, ')}')
		osd:put(
			'{\\bord1\\fs',
			top_fs,
			'\\fnmonospace\\q2\\an',
			mouse_chapter and align or 4,
			'}'
		)
		osd:put(
			'{\\clip(',
			top_small and box_x0 or main_x0,
			',',
			y0,
			',',
			top_small and box_x1 or main_x1,
			',',
			y0 + top_fs,
			')}'
		)
		if mouse_chapter then
			osd:put(
				top_small and '' or '\\h',
				osd.ass_escape(mouse_chapter.title),
				top_small and '' or '\\h'
			)
		else
			if not old_title then
				old_title = title.get_current_ass() or ''
			end
			osd:put(old_title)
			if chapter_pos then
				osd:put(' \u{2022} ', chapter_pos.title)
			end
		end
		osd:put('\n')

		if mouse_chapter and not top_small then
			osd:put('{\\r\\pos(', x0, ',', y0, ')}', '{\\bord1\\3c&HFFFFFF&}')
			osd:draw_begin()
			osd:draw_move(0, 0)
			osd:draw_line(0, top_fs)
			osd:draw_end()
			osd:put('\n')
		end
	end

	do
		local scaled_margin_bottom = osd.height ~= 0
				and (osd.height - box_y0) / osd.height * 720
			or 0
		set_sub_margin_y(base_sub_margin_y + math.ceil(scaled_margin_bottom))
	end

	osd:update()
end
update = osd.update_wrap(update)

hide_timeout = mp.add_timeout(1.5, function()
	visible = false
	update()
end)
hide_timeout:kill()

utils.register_script_messages('osd-bar', {
	visibility = function(action)
		local old_visibility = visibility
		set_visibility(action)
		if old_visibility ~= visibility then
			mp.osd_message(string.format('Visibility: %s', visibility))
		end
	end,
	seek = function(...)
		mp.commandv('no-osd', 'seek', ...)
		set_visibility('blink')
	end,
})

update()

mp.set_property_native('osc', false)
