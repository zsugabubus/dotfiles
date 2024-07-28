local osd = require('osd').new()
local mode = require('mode').new()
local utils = require('utils')

local visible = false
local cursor_type, cursor_id = 'video', 0
local props = {}
local page_size = 21

local old_visible

local update

local function set_visible(action)
	visible = utils.reduce_bool(visible, action)
	update()
end

local CURSOR_TYPE_UP = { video = 'sub', audio = 'video', sub = 'audio' }
local CURSOR_TYPE_DOWN = { video = 'audio', audio = 'sub', sub = 'video' }

local function set_cursor(action)
	if action == 'up' then
		cursor_id = cursor_id - 1
		if cursor_id < 0 then
			cursor_type = CURSOR_TYPE_UP[cursor_type]
			return set_cursor('last')
		end
	elseif action == 'down' then
		cursor_id = cursor_id + 1
		if cursor_id > #props['track-list/type'][cursor_type] then
			cursor_type = CURSOR_TYPE_DOWN[cursor_type]
			return set_cursor('first')
		end
	elseif action == 'first' then
		cursor_id = 0
	elseif action == 'last' then
		cursor_id = #props['track-list/type'][cursor_type]
	elseif action == 'group-up' then
		return set_cursor(CURSOR_TYPE_UP[cursor_type])
	elseif action == 'group-down' then
		return set_cursor(CURSOR_TYPE_DOWN[cursor_type])
	elseif action == 'audio' or action == 'video' or action == 'sub' then
		cursor_type = action
		local x = props['track-list/selected'][action]
		cursor_id = x and x.id or 0
	elseif type(action) == 'number' then
		local n = #props['track-list/type'][cursor_type]
		if action < 0 or action > n then
			return false
		end
		cursor_id = action
	end

	update()

	return true
end

local function set_enabled(action)
	local selected_track = props['track-list/selected'][cursor_type]
	local enabled = selected_track and selected_track.id == cursor_id
	enabled = utils.reduce_bool(enabled, action)
	mp.set_property_native(cursor_type, enabled and cursor_id or 0)
	if cursor_type == 'sub' then
		mp.set_property_native('sub-visibility', true)
	end
end

local function update_property(name, value)
	props[name] = value

	if name == 'track-list' then
		local x = { video = {}, audio = {}, sub = {} }
		for _, track in ipairs(value) do
			table.insert(x[track.type], track)
		end
		props['track-list/type'] = x

		if #value > 0 then
			cursor_id = math.min(cursor_id, #x[cursor_type])
		end

		local x = {}
		for _, track in ipairs(value) do
			if track.selected then
				x[track.type] = track
			end
		end
		props['track-list/selected'] = x
	end

	update()
end

local TRACK_FLAGS = {
	{ 'forced' },
	{ 'visual-impaired' },
	{ 'hearing-impaired' },
	{ 'external' },
	{ 'albumart', 'cover' },
	{ 'default' },
}

local function osd_put_track(track)
	local current = track.type == cursor_type and cursor_id == track.id

	osd:N()
	osd:put_cursor(current)
	osd:bold(current)
	osd:put_marker(track.selected)
	osd:put(string.upper(string.sub(track.type, 1, 1)), ':')
	osd:h()
	osd:put(track.id, ':')
	osd:h()

	osd:putf('[%s] ', track.lang or 'und')

	if track.title then
		osd:put("'")
		osd:str(track.title)
		osd:put("' ")
	end

	osd:put('(')

	osd:put(track.codec)

	if track['demux-w'] then
		osd:putf(' %dx%d', track['demux-w'], track['demux-h'])
	elseif track.type == 'video' and track.selected then
		local pars = props['video-params'] or props['video-out-params']
		if pars then
			osd:putf(' %dx%d', pars.w, pars.h)
		end
	end

	if
		track['demux-channels']
		and not string.find(track['demux-channels'], 'unknown')
	then
		osd:put(' ', track['demux-channels'])
	else
		local pars = props['audio-params'] or props['audio-out-params']
		if
			track.type == 'audio'
			and track.selected
			and pars
			and pars['hr-channels']
		then
			osd:putf(' ', pars['hr-channels'])
		elseif track['demux-channel-count'] then
			osd:putf(' %dch', track['demux-channel-count'])
		end
	end

	if track['demux-samplerate'] then
		osd:putf(' %dHz', track['demux-samplerate'])
	end

	if track['demux-fps'] then
		osd:putf(' %dfps', math.ceil(track['demux-fps']))
	end

	if track['demux-rotation'] then
		osd:putf(' %ddeg', track['demux-rotation'])
	end

	osd:put(')')

	for _, flag in ipairs(TRACK_FLAGS) do
		local key, display = unpack(flag)
		if track[key] then
			osd:putf(' (%s)', display or key)
		end
	end

	if track.selected then
		if track.type == 'audio' and props['mute'] then
			osd:put(' (muted)')
		elseif track.type == 'sub' and not props['sub-visibility'] then
			osd:put(' (hidden)')
		end
	end

	osd:bold(false)
end

local function osd_put_track_list(name, track_type, paginate)
	osd:bold(true)
	osd:put(name)
	osd:bold(false)
	osd:put(' Tracks:')

	local tracks = props['track-list/type'][track_type]
	local selected_track = props['track-list/selected'][track_type]
	local top, bottom

	if paginate and cursor_type ~= track_type then
		local more = #tracks - (selected_track and 1 or 0)
		if more > 0 then
			osd:italic(true)
			osd:put(' ', more, ' more tracks')
			osd:italic(false)
		end
		if selected_track then
			top, bottom = selected_track.id, selected_track.id
		else
			top, bottom = 0, 0
		end
	elseif paginate then
		top = math.max(0, cursor_id - (page_size - 1) / 2)
		bottom = math.min(top + (page_size - 1), #tracks)
		top = math.max(0, bottom - (page_size - 1))
	else
		top, bottom = 0, #tracks
	end

	if top == 0 then
		top = top + 1
		osd:N()
		local current = cursor_type == track_type and cursor_id == 0
		osd:put_cursor(current)
		osd:bold(current)
		osd:put_marker(not selected_track)
		osd:put(string.upper(string.sub(track_type, 1, 1)), ': ')
		osd:put('0: none')
		osd:bold(false)
	end

	for i = top, bottom do
		osd_put_track(tracks[i])
	end

	osd:N()
end

function update()
	if old_visible ~= visible then
		old_visible = visible

		mp.unobserve_property(update_property)
		mp.observe_property('track-list', 'native', update_property)

		if visible then
			mp.observe_property('audio-out-params', 'native', update_property)
			mp.observe_property('audio-params', 'native', update_property)
			mp.observe_property('mute', 'native', update_property)
			mp.observe_property('sub-visibility', 'native', update_property)
			mp.observe_property('video-out-params', 'native', update_property)
			mp.observe_property('video-params', 'native', update_property)
			osd.observe_fsc_properties(update_property)
			mode:add_key_bindings()
		else
			mode:remove_key_bindings()
			osd:remove()
		end

		return
	end

	if not visible then
		return
	end

	local paginate = #props['track-list'] > page_size
	local more_lines = paginate
			and math.min(
				math.max(
					#props['track-list/type']['audio'],
					#props['track-list/type']['video'],
					#props['track-list/type']['sub']
				),
				page_size - 1
			)
		or #props['track-list']

	osd:clear()
	osd:put_fsc(props, 3 * 3 + more_lines, 0.9)
	osd:fn_symbols()

	osd_put_track_list(osd.VIDEO_ICON .. ' Video', 'video', paginate)
	osd:N()
	osd_put_track_list(osd.AUDIO_ICON .. ' Audio', 'audio', paginate)
	osd:N()
	osd_put_track_list(osd.SUBTITLE_ICON .. ' Subtitle', 'sub', paginate)

	osd:update()
end
update = osd.update_wrap(update)

mode:map({
	a = function()
		set_cursor('audio')
	end,
	v = function()
		set_cursor('video')
	end,
	s = function()
		set_cursor('sub')
	end,
	TAB = function()
		set_cursor('group-down')
	end,
	['Shift+TAB'] = function()
		set_cursor('group-up')
	end,
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
	SPACE = function()
		set_enabled('toggle')
	end,
	ENTER = 'SPACE',
	ESC = function()
		set_visible('hide')
	end,
	['0..9'] = function(i)
		if set_cursor(i) then
			set_enabled('toggle')
		end
	end,
})

utils.register_script_messages('osd-tracks', {
	visibility = set_visible,
	cursor = function(action)
		set_visible('show')
		set_cursor(action)
	end,
})

update()
