local title = require('title')
local Osd = require('osd')
local osd = Osd.new()

local COMPLEX = {complex=true}

local mode = 'auto'
local visible = false
local timeout

local text_osd = mp.create_osd_overlay('ass-events')
text_osd.hidden = true
text_osd.compute_bounds = true
local fsx_cache = {}

local props = {
	-- Queried just once.
	['sub-margin-y']=mp.get_property_native('sub-margin-y'),
}
local mouse_time
local mouse_chapter
local old_mouse_y
local old_title
local old_sub_margin_y

local function seek(e)
	mp.commandv('no-osd', 'seek', mouse_time, 'absolute+exact')
	if e.event ~= 'up' then
		mp.add_forced_key_binding('MOUSE_MOVE', 'MOUSE_MOVE', function()
			mp.commandv(
				'no-osd',
				'seek',
				mouse_time,
				props['duration'] < 10 * 60
					and 'absolute+exact'
					or 'absolute+keyframes'
			)
		end)
	else
		mp.remove_key_binding('MOUSE_MOVE')
	end
end

local function go_to_chapter(e)
	if e.event ~= 'up' then
		if not mouse_chapter then
			mp.commandv('no-osd', 'seek', '0', 'absolute+exact')
			return
		end

		mp.commandv('set', 'chapter', mouse_chapter.id .. '')
		mp.add_forced_key_binding('MOUSE_MOVE', 'MOUSE_MOVE', function()
			mp.commandv('set', 'chapter', mouse_chapter.id .. '')
		end)
	else
		mp.remove_key_binding('MOUSE_MOVE')
	end
end

local function measure_text(size)
	size = math.floor(size)

	local width = fsx_cache[size]
	if width == nil then
		text_osd.res_y = size * 2
		text_osd.res_x = size * 2
		text_osd.data = ('{\\q2\\fs%d\\fnmonospace}00'):format(size)
		local bounds = text_osd:update()
		text_osd:remove()

		width = bounds.x1 / 2
		fsx_cache[size] = width
	end

	return width
end

local function human_time(time)
	local neg = time < 0
	time = math.abs(time)
	local hour = math.floor(time / 3600)
	local min = math.floor(time / 60 % 60)
	local sec = math.floor(time % 60)
	return
		neg and '-' or '',
		hour < 10 and '0' or '', hour, ':',
		min < 10 and '0' or '', min, ':',
		sec < 10 and '0' or '', sec
end

local function human_duration(duration)
	local min = math.floor(duration / 60)
	local sec = math.floor(duration % 60)
	if 0 < min then
		return
			min, 'm',
			sec < 10 and '0' or '', sec, 's'
	else
		return sec < 10 and ' ' or '', sec, 's'
	end
end

local update_mode
local function _update()
	mp.unregister_idle(_update)

	osd.res_x, osd.res_y = mp.get_osd_size()

	local main_fs = math.max(math.floor(math.min(osd.res_x, osd.res_y) / 23), 30)

	local top_fs = main_fs * .5

	local side_width = 11 * measure_text(main_fs)
	local box_width = osd.res_x
	local top_small = box_width < 4 * side_width
	local prog_small = box_width < 3 * side_width
	local box_height = top_fs + (top_small and top_fs or 0) + main_fs
	local box_x0 = 0
	local box_x1 = box_x0 + box_width
	local box_y1 = osd.res_y
	local box_y0 = box_y1 - box_height

	local main_width = box_width - (prog_small and 0 or 2 * side_width)
	local main_height = main_fs
	local main_x0 = box_x0 + (prog_small and 0 or side_width)
	local main_x1 = main_x0 + main_width
	local main_y0 = box_y1 - main_height
	local main_y1 = main_y0 + main_height
	local main_yc = (main_y0 + main_y1) / 2

	local percent = (props['percent-pos'] or 0) / 100
	local prog_margin = 2
	local prog_x0 = main_x0 + prog_margin
	local prog_y0 = main_y0 + prog_margin
	local prog_width = main_width - 2 * prog_margin
	local prog_height = main_height - 2 * prog_margin
	local prog_pos = prog_x0 + prog_width * percent

	local duration = props['duration'] or 0

	local mouse = props['mouse-pos']
	local mouse_hit = mouse.hover and (
		(box_x0 <= mouse.x and mouse.x <= box_x1) and
		(box_y0 <= mouse.y and mouse.y <= box_y1)
	)
	local mouse_main_hit = mouse_hit and (
		main_y0 <= mouse.y and
		mouse.y < main_y0 + box_height
	)
	local mouse_percent = (mouse.x - prog_x0) / prog_width
	local mouse_prog_hit = mouse_main_hit and (
		0 <= mouse_percent and mouse_percent < 1
	)
	mouse_time = duration * mouse_percent

	if mode == 'auto' then
		if mouse_hit then
			timeout:kill()
			if not visible then
				visible = true
				update_mode()
				return
			end
		-- Blink when cursor is moved close to the bar.
		elseif
			old_mouse_y ~= mouse.y and
			mouse.hover and
			osd.res_y * 2 / 3 <= mouse.y
		then
			old_mouse_y = mouse.y
			visibility('blink')
		-- Blinking is over.
		elseif
			not timeout:is_enabled()
		then
			if visible then
				visible = false
				update_mode()
				return
			end
		end
	end

	if not visible then
		return
	end

	local cache = props['demuxer-cache-state']

	function osd_clip_main(prog)
		osd:append('{\\clip(',
			prog == 'right' and prog_pos or main_x0, ',',
			main_y0, ',',
			prog == 'left' and prog_pos or main_x1, ',',
			main_y1,
		')}')
	end

	function time2x(time)
		return 0 < duration and time / duration * prog_width or 0
	end

	osd.data = {}

	-- Bar background.
	osd:append('{\\r\\pos(', box_x0, ',', box_y0, ')}')
	osd:append('{\\bord0\\1a&H50&\\1c&H000000&}')
	osd:draw_begin()
	osd:draw_rect_wh(0, 0, box_width, box_height)
	osd:draw_end()
	osd:append('\n')

	-- Progress bar.
	osd:append('{\\r\\pos(', main_x0, ',', main_y0, ')}')
	osd:append('{\\bord0\\1a&HE0&\\1c&HFFFFFF&}')
	osd:draw_begin()
	osd:draw_rect_wh(
		0, 0,
		math.ceil(main_width), math.ceil(main_height)
	)
	osd:draw_end()
	osd:append('\n')

	-- Filled progress bar.
	osd:append('{\\r\\pos(', prog_x0, ',', prog_y0, ')}')
	osd:append('{\\bord0\\1a&H10&\\1c&HFFFFFF&}')
	osd:draw_begin()
	osd:draw_rect_wh(
		0, 0,
		prog_width * percent, prog_height
	)
	osd:draw_end()
	osd:append('\n')

	-- Cache ranges.
	if cache then
		local line_margin = math.ceil(main_height / 2 - main_fs / 20)
		local x, y = main_x0 + prog_margin, main_y0

		function draw()
			for _, range in ipairs(cache['seekable-ranges']) do
				osd:draw_rect(
					math.floor(time2x(range.start)), line_margin,
					math.floor(time2x(range['end'])), main_height - line_margin
				)
			end
		end

		-- Part over filled part.
		osd:append('{\\r\\pos(', x, ',', y, ')\\bord0\\1a&H10&\\1c&H000000&}')
		osd_clip_main('left')
		osd:draw_begin()
		draw()
		osd:draw_end()
		osd:append('\n')

		-- Part over unfilled part.
		osd:append('{\\r\\pos(', x, ',', y, ')\\bord0\\1a&H10&\\1c&HFFFFFF&}')
		osd_clip_main('right')
		osd:draw_begin()
		draw()
		osd:draw_end()
		osd:append('\n')
	end

	if not (prog_small and mouse_prog_hit) then
		local fs = main_fs * (prog_small and .8 or 1)
		-- Left block.
		osd:append('{\\r\\pos(',
			box_x0 + (prog_small and 0 or side_width / 2), ',',
			main_yc,
		')}')
		osd:append(
			'{\\bord2\\fs',
			fs,
			'\\fnmonospace\\an',
			prog_small and '4}\\h' or '5}'
		)
		osd:append(human_time(props['time-pos'] or 0))
		osd:append('\n')

		-- Right block.
		osd:append('{\\r\\pos(',
			box_x1 - (prog_small and 0 or side_width / 2), ',',
			main_yc,
		')}')
		osd:append(
			'{\\bord2\\fs',
			fs,
			'\\fnmonospace\\an',
			prog_small and '6}' or '5}'
		)
		if mouse_prog_hit then
			osd:append(human_time(-(duration - mouse_time)))
		elseif mouse_main_hit == props['demuxer-via-network'] then
			osd:append(human_time(duration))
		else
			osd:append(human_time(-(props['playtime-remaining'] or 0)))
		end
		osd:append(
			prog_small and '\\h' or '',
			'\n'
		)
	end

	-- Top left block.
	osd:append('{\\r\\pos(',
		box_x0 + side_width / 2, ',',
		math.floor(box_y0 + top_fs / 2),
	')}')
	osd:append('{\\bord1\\fs', top_fs, '\\fnmonospace\\an5}')
	osd:append(props['playlist-pos'], '/', props['playlist-count'])
	osd:append('\n')

	-- Top right block.
	if cache then
		osd:append('{\\r\\pos(',
			box_x1 - side_width / 2, ',',
			math.floor(box_y0 + top_fs / 2),
		')}')
		osd:append('{\\bord1\\fs', top_fs, '\\fnmonospace\\an5}')
		osd:append('Cache: ', human_duration(cache['cache-duration'] or 0))
		osd:append('/', math.floor((cache['total-bytes'] or 0) / 1000 / 1000), 'M')
		osd:append('\n')
	end

	do
		mouse_chapter = nil
		local chapters = props['chapter-list']
		if chapters then
			local tri_height = main_fs / 8
			local tri_side = tri_height / math.sin(45 / 180 * math.pi)

			osd:append('{\\r\\pos(',
				main_x0 + prog_margin, ',',
				main_y0, ')\\bord1\\1a&H10&\\1c&HFFFFFF&}'
			)
			osd:draw_begin()
			for i, chapter in ipairs(chapters) do
				chapter.id = i - 1
				local x = time2x(chapter.time)
				if mouse_prog_hit and chapter.time <= mouse_time and (
					not mouse_chapter or
					mouse_chapter.time < chapter.time
				) then
					mouse_chapter = chapter
				end
				osd:draw_triangle(
					x, tri_height,
					90 + 45, tri_side,
					90 - 45, tri_side
				)
				osd:draw_triangle(
					x, main_height - tri_height,
					-90 + 45, tri_side,
					-90 - 45, tri_side
				)
			end
			osd:draw_end()
			osd:append('\n')
		end
	end

	do
		function draw_ab(prop, rot, color)
			local time = props[prop]
			if time == 'no' or not time then
				return
			end

			local tri_height = main_fs / 5
			local tri_side = tri_height / math.sin(45 / 180 * math.pi)

			osd:append('{\\r\\pos(',
				main_x0 + prog_margin, ',',
				main_y0, ')\\bord1\\1a&H10&\\1c&H', color, '&}'
			)
			osd:draw_begin()
			local x = time2x(math.min(time, duration))
			osd:draw_triangle(
				x, tri_height,
				90, tri_height,
				rot, tri_side
			)
			osd:draw_triangle(
				x, main_height - tri_height,
				-90, tri_height,
				-rot, tri_side
			)
			osd:draw_end()
			osd:append('\n')
		end
		draw_ab('ab-loop-a', 90 + 45, '0000FF')
		draw_ab('ab-loop-b', 90 - 45, '00FF00')
	end

	-- Mouse position.
	if mouse_prog_hit then
		local mouse_align = mouse.x < osd.res_x / 2 and 4 or 6

		-- A second, 2-width white outline so it is legible over cached ranges that
		-- is also black.
		osd:append('{\\r\\1c&HFFFFFF&\\fs', main_fs, '\\fnmonospace}')
		osd:append('{\\pos(', mouse.x, ',', main_yc, ')}')
		osd_clip_main('left')
		osd:append('{\\bord4\\an', mouse_align, '}')
		osd:append('{\\3c&HFFFFFF&}\\h')
		osd:append(human_time(mouse_time))
		osd:append('\\h\n')

		osd:append('{\\r\\1c&HFFFFFF&\\fs', main_fs, '\\fnmonospace}')
		osd:append('{\\pos(', mouse.x, ',', main_yc, ')}')
		osd_clip_main()
		osd:append('{\\bord2\\an', mouse_align, '}')
		osd:append('{\\3c&H000000&}\\h')
		osd:append(human_time(mouse_time))
		osd:append('\\h\n')
	end

	-- Top center block.
	do
		local x0 = top_small
			and box_x0
			or (mouse_chapter
				and prog_x0 + time2x(mouse_chapter.time)
				or main_x0
			)
		local y0 = box_y0 + (top_small and top_fs or 0)
		local align = x0 < osd.res_x / 2 and 4 or 6
		osd:append('{\\r\\pos(', x0, ',', y0 + top_fs / 2, ')}')
		osd:append(
			'{\\bord1\\fs',
			top_fs,
			'\\fnmonospace\\q2\\an',
			mouse_chapter and align or 4,
			'}'
		)
		osd:append('{\\clip(',
			top_small and box_x0 or main_x0, ',',
			y0, ',',
			top_small and box_x1 or main_x1, ',',
			y0 + top_fs,
		')}')
		if mouse_chapter then
			osd:append(
				top_small and '' or '\\h',
				osd.ass_escape(mouse_chapter.title),
				top_small and '' or '\\h'
			)
		else
			if not old_title then
				old_title = title.get_current()
			end
			osd:append(old_title)
		end
		osd:append('\n')

		if mouse_chapter and not top_small then
			osd:append(
				'{\\r\\pos(', x0, ',', y0, ')}',
				'{\\bord1\\3c&HFFFFFF&}'
			)
			osd:draw_begin()
			osd:draw_move(0, 0)
			osd:draw_line(0, top_fs)
			osd:draw_end()
			osd:append('\n')
		end
	end

	if mouse_prog_hit then
		-- Okay. Fuck my life. MBTN_LEFT (but only this) sends "up" event as soon
		-- as MOUSE_MOVEs.
		mp.add_forced_key_binding('MBTN_RIGHT', 'MBTN_RIGHT', go_to_chapter, COMPLEX)
		mp.add_forced_key_binding('MBTN_LEFT', 'MBTN_LEFT', seek, COMPLEX)
		mp.add_forced_key_binding('MBTN_MID', 'MBTN_MID', seek, COMPLEX)
	else
		mp.remove_key_binding('MBTN_LEFT')
		mp.remove_key_binding('MBTN_MID')
		mp.remove_key_binding('MBTN_RIGHT')
		mp.remove_key_binding('MOUSE_MOVE')
	end

	do
		local scaled_margin_bottom = osd.res_y ~= 0
			and (osd.res_y - box_y0) / osd.res_y * 720
			or 0
		local sub_margin_y = props['sub-margin-y'] + math.ceil(scaled_margin_bottom)
		if old_sub_margin_y ~= sub_margin_y then
			-- set_property() is handled only after window resize, commandv() applied
			-- immediately (when subtitle changes).
			mp.commandv('set', 'sub-margin-y', sub_margin_y)
		end
	end

	osd:update()
end
function update()
	mp.unregister_idle(_update)
	mp.register_idle(_update)
end

local function update_property(name, value)
	if
		name == 'metadata' or
		name == 'media-title' or
		name == 'playlist-pos'
	then
		old_title = nil
	end

	local old = props[name]
	props[name] = value
	if old and value then
		-- Drop changes with too much precision.
		if
			name == 'time-pos' or
			name == 'playtime-remaining' or
			name == 'duration'
		then
			if math.floor(old) == math.floor(value) then
				return
			end
		elseif
			name == 'demuxer-cache-state'
		then
			-- "seekable-ranges" are not worth frequent updates.
			if
				math.floor(old['cache-duration']) ==
				math.floor(value['cache-duration'])
			then
				return
			end
		elseif
			name == 'percent-pos'
		then
			-- Not exactly res_x but near to it. And least we do not depend on the
			-- implementation that much regarding how long the progress bar is.
			if
				math.floor(osd.res_x * old / 100) ==
				math.floor(osd.res_x * value / 100)
			then
				return
			end
		end
	end

	update()
end

local function observe_properties(type, names)
	for _, prop in ipairs(names) do
		mp.observe_property(prop, type, update_property)
	end
end

update_mode = function()
	if mode == 'hide' then
		visible = false
	elseif mode == 'show' then
		visible = true
	end

	mp.unobserve_property(update_property)

	if mode == 'auto' or visible then
		observe_properties('native', {
			'mouse-pos',
		})

		observe_properties(nil, {
			'osd-dimensions',
		})
	end

	if visible then
		observe_properties('native', {
			'ab-loop-a',
			'ab-loop-b',
			'chapter-list',
			'demuxer-cache-state',
			'demuxer-via-network',
			'duration',
			'pause', -- To show exact values on pause.
			'percent-pos',
			'playlist-count',
			'playlist-pos',
			'playtime-remaining',
			'time-pos',
		})

		observe_properties(nil, {
			'metadata',
			'media-title',
		})
	else
		timeout:kill()
	end

	if not visible then
		osd:remove()
		-- Reset.
		mp.commandv('set', 'sub-margin-y', props['sub-margin-y'])
	end
end

function visibility(action)
	if action == 'toggle' then
		mode = mode == 'auto' and 'show' or 'auto'
	elseif action == 'blink' then
		if mode ~= 'auto' then
			return
		end

		timeout:kill()
		timeout:resume()

		if visible then
			return
		end

		visible = true
	else
		mode = action
	end

	update_mode()
end

timeout = mp.add_timeout(
	mp.get_property_native('osd-duration') / 1000,
	function()
		visible = false
		update_mode()
	end
)
timeout:kill()

mp.register_script_message('visibility', function(...)
	local old_mode = mode
	visibility(...)
	if old_mode ~= mode then
		mp.osd_message(('Visibility: %s'):format(mode))
	end
end)

mp.register_script_message('seek', function(...)
	mp.commandv('no-osd', 'seek', ...)
	visibility('blink')
end)

update_mode()
