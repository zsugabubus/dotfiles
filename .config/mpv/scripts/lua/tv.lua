local json_decode = require('mp.utils').parse_json
local mode = require('mode').new()
local osd = require('osd').new()
local utils = require('utils')

local function system(args)
	local child = mp.command_native({
		name = 'subprocess',
		playback_only = false,
		capture_stdout = true,
		args = args,
	})
	assert(child.status == 0)
	return child.stdout
end

local function tmpname()
	local s = os.tmpname()
	mp.register_event('shutdown', function()
		os.remove(s)
	end)
	return s
end

local get_mediaklikk_streams = (function()
	local DAY = 24 * 60 * 60
	local MINUTE = 60

	local streams = {}
	local streams_etag_file

	local function parse_time(s)
		local t = os.date('*t')
		t.hour, t.min = string.match(s, '^(%d+):(%d+)$')
		t.sec = 0
		return os.time(t)
	end

	local function fetch(url, etag_file)
		local args = {
			'curl',
			'--silent',
			'--compressed',
			'--header',
			'Origin: https://m4sport.hu',
			'--header',
			'Referer: https://m4sport.hu/',
			url,
		}

		if etag_file then
			table.insert(args, '--etag-save')
			table.insert(args, etag_file)
			table.insert(args, '--etag-compare')
			table.insert(args, etag_file)
		end

		return system(args)
	end

	local function get_url(stream)
		local response = fetch(
			string.format(
				'https://player.mediaklikk.hu/playernew/player.php?video=%s&noflash=yes',
				assert(stream.code)
			)
		)
		local m = string.match(response, '"https[^"]-index%.m3u8')
		if not m then
			return
		end
		local url_json = m .. '"'
		local url = json_decode(url_json)
		return url
	end

	return function()
		if not streams_etag_file then
			streams_etag_file = tmpname()
		end

		local response = fetch(
			'https://m4sport.hu/wp-content/plugins/hms-global-widgets/interfaces/streamJSONs/StreamSelector.json',
			streams_etag_file
		)

		-- 304 Not Modified
		if response == '' then
			return streams
		end

		local result = assert(json_decode(response))
		local now = os.time()
		local by_code = {}

		for _, x in ipairs(result.streams) do
			local code = x.code
			local start_time = parse_time(x.time)
			local end_time = parse_time(x.endTime)

			if end_time < start_time then
				end_time = end_time + DAY
			end

			if now + DAY / 2 < start_time then
				start_time = start_time - DAY
				end_time = end_time - DAY
			end

			local stream = by_code[code]
			if not stream then
				stream = {
					code = code,
					name = x.name,
					get_url = get_url,
				}
				by_code[code] = stream
			end

			local show = {
				title = x.title,
				start_time = start_time,
				end_time = end_time,
			}

			if show.start_time <= now and now < show.end_time + MINUTE then
				stream.current = show
			elseif
				now < show.start_time
				and (
					not stream.upcoming or show.start_time < stream.upcoming.start_time
				)
			then
				stream.upcoming = show
			end
		end

		streams = {}

		for _, stream in pairs(by_code) do
			table.insert(streams, stream)
		end

		table.sort(streams, function(a, b)
			return string.upper(a.name) < string.upper(b.name)
		end)

		return streams
	end
end)()

local visible = false
local cursor = 0
local props = {}
local streams

local old_visible

local update

local function set_visible(action)
	visible = utils.reduce_bool(visible, action)
	update()
end

local function set_cursor(action)
	if action == 'up' then
		cursor = cursor - 1
		if cursor < 1 then
			return set_cursor('last')
		end
	elseif action == 'down' then
		cursor = cursor + 1
		if cursor > #streams then
			return set_cursor('first')
		end
	elseif action == 'first' then
		cursor = 1
	elseif action == 'last' then
		cursor = #streams
	elseif type(action) == 'number' then
		if action < 1 or action > #streams then
			return false
		end
		cursor = action
	end

	update()

	return true
end

local function reload()
	streams = get_mediaklikk_streams()

	if not set_cursor(cursor) then
		set_cursor('first')
	end
end

local function open()
	if not streams then
		return
	end

	local stream = streams[cursor]
	if not stream then
		return
	end

	mp.osd_message('Opening…')

	local url = stream:get_url()
	if not url then
		mp.osd_message('Cannot open: No URL')
		return
	end

	url = string.format('%s#%s', url, stream.name)
	mp.commandv('loadfile', url, 'replace')

	mp.osd_message('')
end

local function update_property(name, value)
	props[name] = value
end

local update_timer
update_timer = mp.add_periodic_timer(30, function()
	if not visible then
		streams = nil
		update_timer:stop()
		return
	end

	reload()
	update()
end, true)

local function osd_put_times(show)
	osd:put(
		os.date('%H:%M', show.start_time),
		'\u{2013}',
		os.date('%H:%M', show.end_time)
	)
end

local function osd_put_progress(show, now)
	local bar_height = 8
	local bar_width = 100

	local progress = (now - show.start_time) / (show.end_time - show.start_time)
	progress = math.max(0, progress)
	progress = math.min(1, progress)

	osd:draw_begin()
	local fill_width = progress * bar_width
	if fill_width > 1 then
		osd:draw_rect(1, 1, fill_width, bar_height - 1)
	end
	osd:draw_rect_border(0, 0, bar_width, bar_height, 1)
	osd:draw_end()
end

function update()
	if old_visible ~= visible then
		old_visible = visible

		mp.unobserve_property(update_property)

		if visible then
			osd.observe_fsc_properties(update_property)
			mode:add_key_bindings()
		else
			mode:remove_key_bindings()
			osd:remove()
		end

		if visible then
			if not streams then
				reload()
			end

			update_timer:resume()
		end
	end

	if not visible then
		return
	end

	local now = os.time()
	local fmt = string.format('%%%dd: ', #tostring(#streams))
	local fsc = osd:compute_fsc(props, #streams * 2, 0.8)

	osd:clear()
	osd:skip_message_line()
	osd:wrap(false)

	for i, stream in ipairs(streams) do
		local current = i == cursor

		osd:r()
		osd:fsc(fsc)
		osd:put_cursor(current)
		osd:c1(stream.current and 0xffffff or 0xbbbbbb)
		osd:putf(fmt, i)
		osd:bold(true)
		osd:str(stream.name)
		osd:bold(false)
		if stream.current or stream.upcoming then
			osd:put(' \u{2013} ')
			osd:str((stream.current or stream.upcoming).title)
		end
		osd:N()

		if stream.current or stream.upcoming then
			osd:fscy0()
			osd:put_cursor(false)
			osd:putf(fmt, i)
			osd:bord(2)
			osd:alpha(0x20)
			osd:fsc(100)
			osd:fs(16)
			if stream.current then
				osd_put_times(stream.current)
				osd:put(' ')
				osd_put_progress(stream.current, now)
				if stream.upcoming then
					osd:put(' ')
					osd_put_times(stream.upcoming)
					osd:put(' ', stream.upcoming.title)
				end
			else
				osd_put_times(stream.upcoming)
			end
			osd:N()
		end
	end

	osd:update()
end
update = osd.update_wrap(update)

mode:map({
	UP = function()
		set_cursor('up')
	end,
	DOWN = function()
		set_cursor('down')
	end,
	HOME = function()
		set_cursor('first')
	end,
	END = function()
		set_cursor('last')
	end,
	ENTER = open,
	ESC = function()
		set_visible('hide')
	end,
	['0..9'] = function(i)
		set_cursor(i)
	end,
})

utils.register_script_messages('tv', {
	visibility = set_visible,
	reload = reload,
})
