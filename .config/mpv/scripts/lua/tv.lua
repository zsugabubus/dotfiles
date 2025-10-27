local json_decode = require('mp.utils').parse_json
local utils = require('utils')

local function system(args)
	local child = mp.command_native({
		name = 'subprocess',
		playback_only = false,
		capture_stdout = true,
		args = args,
	})
	if child.status == 0 then
		return child.stdout
	end
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
		t.hour, t.min = s:match('^(%d+):(%d+)$')
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
			'--max-time',
			'3',
			url,
		}

		if etag_file then
			table.insert(args, '--etag-save')
			table.insert(args, etag_file)
			table.insert(args, '--etag-compare')
			table.insert(args, etag_file)
		end

		return system(args) or ''
	end

	local function get_url(stream)
		local response = fetch(
			('https://player.mediaklikk.hu/playernew/player.php?video=%s&noflash=yes'):format(
				assert(stream.code)
			)
		)
		local m = response:match('"https[^"]-index%.m3u8')
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
			return a.name:upper() < b.name:upper()
		end)

		return streams
	end
end)()

local function open(stream)
	mp.osd_message(('Opening %s…'):format(stream.name))

	local url = stream:get_url()
	if not url then
		mp.osd_message(('Cannot open %s'):format(stream.name))
		return
	end

	mp.commandv('loadfile', ('%s#%s'):format(url, stream.name), 'replace')

	mp.osd_message('')
end

local function format_show_time(show)
	return os.date('%H:%M', show.start_time)
		.. '-'
		.. os.date('%H:%M', show.end_time)
end

local PROGRESS_BLOCKS =
	{ ' ', '▏', '▎', '▍', '▌', '▋', '▊', '▉', '█' }

local function format_progress(percent)
	local width = 5
	local s = ''
	for i = 1, width do
		local block_percent = math.max(math.min(percent * width - (i - 1), 1), 0)
		s = s .. PROGRESS_BLOCKS[math.ceil(block_percent * 8) + 1]
	end
	return s
end

local function get_show_progress(show, now)
	return (now - show.start_time) / (show.end_time - show.start_time)
end

local function get_items(streams)
	local now = os.time()
	local items = {}
	for i, stream in ipairs(streams) do
		local letter = string.char(('a'):byte() - 1 + i)
		local progress = 0
		local current = ''
		local upcoming = ''
		if stream.current then
			progress = get_show_progress(stream.current, now)
			current = (' • (%s) %s'):format(
				format_show_time(stream.current),
				stream.current.title
			)
		end
		if stream.upcoming then
			upcoming = (' → (%s) %s'):format(
				format_show_time(stream.upcoming),
				stream.upcoming.title
			)
		end
		table.insert(
			items,
			('%s: %s %s%s%s'):format(
				letter,
				format_progress(progress),
				stream.name,
				current,
				upcoming
			)
		)
	end
	return items
end

utils.register_script_messages('tv', {
	select = function()
		local streams = get_mediaklikk_streams()
		require('mp.input').get({
			prompt = 'TV',
			items = get_items(streams),
			default_text = '^',
			select_one = true,
			submit = function(i)
				open(streams[i])
			end,
		})
	end,
})
