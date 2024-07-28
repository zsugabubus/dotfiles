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
local old_prog_hover
local old_hover
local old_mouse_y = 0
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
	local small = box_width < 4 * side_width
	local very_small = box_width < 2 * side_width
	local box_height = top_fs + (small and top_fs or 0) + main_fs
	local box_x0 = 0
	local box_x1 = box_x0 + box_width
	local box_y1 = osd.height
	local box_y0 = box_y1 - box_height

	local main_width = box_width - (small and 0 or 2 * side_width)
	local main_height = main_fs
	local main_x0 = box_x0 + (small and 0 or side_width)
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
	local mouse_x = mouse.x
	local mouse_y = mouse.y
	local hover = mouse.hover
	local box_hover = hover
		and (
			(box_x0 <= mouse_x and mouse_x <= box_x1)
			and (box_y0 <= mouse_y and mouse_y <= box_y1)
		)
	local main_hover = box_hover
		and (main_y0 <= mouse_y and mouse_y < main_y0 + box_height)
	local mouse_percent = (mouse_x - prog_x0) / prog_width
	local prog_hover = main_hover and (0 <= mouse_percent and mouse_percent < 1)
	mouse_time = duration * mouse_percent

	if visibility == 'auto' then
		local trigger_y = math.min(osd.height * 2 / 3, box_y0)
		if box_hover then
			visible = true
			hide_timeout:kill()
		elseif old_hover and not hover then
			visible = false
		elseif
			old_mouse_y ~= mouse_y
			and mouse_y >= trigger_y
			and (visible or mouse_y > old_mouse_y)
		then
			visible = true
			hide_timeout:kill()
			hide_timeout:resume()
		elseif mouse_y < trigger_y and old_mouse_y >= trigger_y then
			visible = false
		end
		old_mouse_y = mouse_y
		old_hover = hover
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
			prog_hover = false
		end
	end

	if old_prog_hover ~= prog_hover then
		old_prog_hover = prog_hover

		if prog_hover then
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
		osd:clip(
			prog == 'right' and prog_pos or main_x0,
			main_y0,
			prog == 'left' and prog_pos or main_x1,
			main_y1
		)
	end

	local function time2x(time)
		return duration > 0 and time / duration * prog_width or 0
	end

	osd:clear()

	-- Bar background.
	do
		osd:r()
		osd:bord(0)
		osd:pos(box_x0, box_y0)
		osd:a1(0x2e)
		osd:c1(0x000000)
		osd:draw_begin()
		osd:draw_rect_wh(0, 0, box_width, box_height)
		osd:draw_end()
		osd:n()
	end

	-- Progress bar.
	do
		osd:r()
		osd:bord(0)
		osd:pos(main_x0, main_y0)
		osd:a1(0xee)
		osd:c1(0xffffff)
		osd:draw_begin()
		osd:draw_rect_wh(0, 0, math.ceil(main_width), math.ceil(main_height))
		osd:draw_end()
		osd:n()
	end

	-- Filled progress bar.
	do
		osd:r()
		osd:bord(0)
		osd:pos(prog_x0, prog_y0)
		osd:a1(0x10)
		osd:c1(0xffffff)
		osd:draw_begin()
		osd:draw_rect_wh(0, 0, prog_fill_width, prog_height)
		osd:draw_end()
		osd:n()
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
			osd:r()
			osd:bord(0)
			osd:pos(x, y)
			osd:a1(0x10)
			osd:c1(0x000000)
			osd_clip_main('left')
			osd:draw_begin()
			draw()
			osd:draw_end()
			osd:n()

			-- Part over unfilled part.
			osd:r()
			osd:bord(0)
			osd:pos(x, y)
			osd:a1(0x10)
			osd:c1(0xffffff)
			osd_clip_main('right')
			osd:draw_begin()
			draw()
			osd:draw_end()
			osd:n()
		end
	end

	if not (small and prog_hover) then
		local fs = main_fs * (small and 0.8 or 1)
		-- Left block.
		osd:r()
		osd:bord(2)
		osd:pos(box_x0 + (small and 0 or side_width / 2), main_yc)
		osd:fs(fs)
		osd:fn_monospace()
		osd:an(small and 4 or 5)
		if small then
			osd:h()
		end
		osd_put_human_time(props['time-pos'] or 0)
		osd:n()

		-- Right block.
		osd:r()
		osd:bord(2)
		osd:pos(box_x1 - (small and 0 or side_width / 2), main_yc)
		osd:fs(fs)
		osd:fn_monospace()
		osd:an(small and 6 or 5)
		if prog_hover then
			osd_put_human_time(-(duration - mouse_time))
		elseif
			main_hover == (props['demuxer-via-network'] or props['speed'] ~= 1)
		then
			osd_put_human_time(duration)
		else
			local time_remaininig = (props['duration'] or 0)
				- (props['time-pos'] or 0)
			local playtime_remaininig = time_remaininig / props['speed']
			osd_put_human_time(-playtime_remaininig)
		end
		if small then
			osd:h()
		end
		osd:n()
	end

	-- Top left block.
	do
		osd:r()
		osd:bord(1)
		osd:pos(box_x0 + side_width / 2, math.floor(box_y0 + top_fs / 2))
		osd:fs(top_fs)
		osd:fn_monospace()
		osd:an(5)
		osd:put(props['playlist-pos'], '/', props['playlist-count'])
		osd:n()
	end

	-- Top right block.
	if cache and not very_small then
		osd:r()
		osd:bord(1)
		osd:pos(box_x1 - side_width / 2, math.floor(box_y0 + top_fs / 2))
		osd:fs(top_fs)
		osd:fn_monospace()
		osd:an(5)
		osd:put('Cache: ')
		osd_put_human_duration(cache['cache-duration'] or 0)
		osd:put('/', math.floor((cache['total-bytes'] or 0) / 1000 / 1000), 'M')
		osd:n()
	end

	-- Chapter markers.
	do
		chapter_pos = nil

		local chapters = props['chapter-list']
		if chapters and #chapters > 0 then
			local tri_height = main_fs / 8
			local tri_side = tri_height / math.sin(45 / 180 * math.pi)

			osd:r()
			osd:pos(main_x0 + prog_margin, main_y0)
			osd:bord(1)
			osd:a1(0x10)
			osd:c1(0xffffff)
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
			osd:n()

			local chapter_at = prog_hover and mouse_time or (props['time-pos'] or 0)

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

			osd:r()
			osd:bord(1)
			osd:pos(main_x0 + prog_margin, main_y0)
			osd:a1(0x10)
			osd:c1(color)
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
			osd:n()
		end

		draw_ab('ab-loop-a', 90 + 45, 0x0000ff)
		draw_ab('ab-loop-b', 90 - 45, 0x00ff00)
	end

	-- Mouse position.
	if prog_hover then
		local mouse_align = mouse_x < osd.width / 2 and 4 or 6
		osd:r()
		osd:c1(0xffffff)
		osd:fs(main_fs)
		osd:fn_monospace()
		osd:pos(mouse_x, main_yc)
		osd_clip_main()
		osd:bord(2)
		osd:an(mouse_align)
		osd:c3(0x000000)
		osd:h()
		osd_put_human_time(mouse_time)
		osd:h()
		osd:n()
	end

	-- Top center block.
	do
		local mouse_chapter = prog_hover and chapter_pos
		local x0 = small and box_x0
			or (mouse_chapter and prog_x0 + time2x(mouse_chapter.time) or main_x0)
		local y0 = box_y0 + (small and top_fs or 0)
		local align = x0 < osd.width / 2 and 4 or 6
		osd:r()
		osd:bord(1)
		osd:pos(x0, y0 + top_fs / 2)
		osd:fs(top_fs)
		osd:fn_monospace()
		osd:wrap(false)
		osd:an(mouse_chapter and align or 4)
		osd:clip(
			small and box_x0 or main_x0,
			y0,
			small and box_x1 or main_x1,
			y0 + top_fs
		)
		if mouse_chapter then
			if not small then
				osd:h()
			end
			osd:str(mouse_chapter.title)
			if not small then
				osd:h()
			end
		else
			if not old_title then
				old_title = title.get_current_ass() or ''
			end
			osd:put(old_title)
			if chapter_pos then
				osd:put(' \u{2022} ', chapter_pos.title)
			end
		end
		osd:n()

		if mouse_chapter and not small then
			osd:r()
			osd:bord(1)
			osd:c3(0xffffff)
			osd:pos(x0, y0)
			osd:draw_begin()
			osd:draw_move(0, 0)
			osd:draw_line(0, top_fs)
			osd:draw_end()
			osd:n()
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
end, true)

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
