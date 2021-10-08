local TRACK_FLAGS = {
	{'forced'},
	{'visual-impaired', 'vi'},
	{'hearing-impaired', 'hi'},
	{'external'},
	{'albumart', 'cover'},
	{'default'},
}

local Mode = require('mode')
local options = require('mp.options')
local osd = require('osd')

local visible = false
local current = 'video'

local opts = {
	font_scale = 0.9,
}
options.read_options(opts, nil, update)

local function switch_track(prop, all)
	local tracks = mp.get_property_native('track-list')
	for i=#tracks,1,-1 do
		local track = tracks[i]
		if (all or track.type == current) and track[prop] then
			mp.set_property_number(track.type, track.id)
		end
	end
end

local function cycle_track(prop, up)
	local tracks, data = mp.get_property_native('track-list')
	local from, to, step
	if up then
		from, to, step = 1, #tracks, 1
	else
		from, to, step = #tracks, 1, -1
	end

	for i=from, to, step do
		local track = tracks[i]
		if track.type == current then
			if track.selected then
				data = track[prop]
				if not data then
					return
				end
			elseif track[prop] == data then
				mp.set_property_number(current, track.id)
				return
			end
		end
	end

	if not data then
		return
	end

	for i=from, to, step do
		local track = tracks[i]
		if track.type == current and track[prop] == data then
			mp.set_property_number(current, track.id)
			return
		end
	end
end

local keys = {
	a={'audios', function()
		current = 'audio'
		update()
	end},
	v={'videos', function()
		current = 'video'
		update()
	end},
	s={'subs', function()
		current = 'sub'
		update()
	end},
	n={'none', function()
		mp.set_property_number(current, 0)
	end},
	d={'default', function()
		switch_track('default', false)
	end},
	D={'default', function()
		switch_track('default', true)
	end},
	f={'forced', function()
		switch_track('forced', false)
	end},
	F={'forced', function()
		switch_track('forced', true)
	end},
	-- Other.
	o={'same language', function()
		cycle_track('lang', true)
	end},
	O={'same language', function()
		cycle_track('lang', false)
	end},
	SPACE={'toggle enabled', function()
		if current == 'audio' then
			mp.commandv('no-osd', 'cycle', 'mute')
		elseif current == 'sub' then
			mp.commandv('no-osd', 'cycle', 'sub-visibility')
		end
	end},
	UP={'switch track', function()
		mp.commandv('no-osd', 'cycle', current, 'down')
	end},
	DOWN={'switch track', function()
		mp.commandv('no-osd', 'cycle', current, 'up')
	end},
	j='DOWN',
	k='UP',
	['Shift+UP']={'select type', function()
		current = ({video='sub', audio='video', sub='audio'})[current]
		update()
	end},
	['Shift+DOWN']={'select type', function()
		current = ({video='audio', audio='sub', sub='video'})[current]
		update()
	end},
	LEFT='Shift+UP',
	RIGHT='Shift+DOWN',
	h='LEFT',
	l='RIGHT',
	TAB='Shift+DOWN',
	['Shift+TAB']='Shift+UP',
	q={'quit', function()
		visible = false
		update_menu()
	end},
	['0..9']={'switch track'},
	t='q',
	ESC='q',
	ENTER='q',
}
for i=0,9 do
	keys[string.char(string.byte('0') + i)] =
		function()
			mp.commandv('no-osd', 'set', current, i)
		end
end
local mode = Mode(keys)

local function osd_append_track(track)
	local enabled = track.selected
	if enabled then
		if track.type == 'audio' then
			enabled = not mp.get_property_native('mute')
		elseif track.type == 'sub' then
			enabled = mp.get_property_native('sub-visibility')
		end
	end

	osd:append(
		'\\N',
		(track.selected and current == track.type and '' or '{\\alpha&HFF}'),
		osd.RIGHT_ARROW,
		'{\\alpha&H00} ',
		(enabled and '●' or '○'), ' ',
		track.id, ': ')

	osd:append('[', track.lang or 'und', '] ')

	if track.title then
		osd:append("'", osd.ass_escape(track.title), "' ")
	end

	osd:append('(')

	osd:append(track.codec)

	if track['demux-w'] then
		osd:append(' ', track['demux-w'], 'x', track['demux-h'])
	elseif track.type == 'video' and track.selected then
		local pars =
			mp.get_property_native('video-params') or
			mp.get_property_native('video-out-params')
		if pars then
			osd:append(' ', pars.w, 'x', pars.h)
		end
	end

	if track['demux-channels'] and 1 ~= track['demux-channels']:find('unknown') then
		osd:append(' ', track['demux-channels'])
	else
		local pars =
			mp.get_property_native('audio-params') or
			mp.get_property_native('audio-out-params')
		if track.type == 'audio' and track.selected and pars and pars['hr-channels'] then
			osd:append(' ', pars['hr-channels'])
		elseif track['demux-channel-count'] then
			osd:append(' ', track['demux-channel-count'], 'ch')
		end
	end

	if track['demux-samplerate'] then
		osd:append(' ', track['demux-samplerate'], 'Hz')
	end

	if track['demux-fps'] then
		osd:append(' ', math.ceil(track['demux-fps']), 'fps')
	end

	if track['demux-rotation'] then
		osd:append(' ', track['demux-rotation'], 'deg')
	end

	osd:append(')')

	for _, flag in ipairs(TRACK_FLAGS) do
		local key, display = table.unpack(flag)
		if track[key] then
			osd:append(' (', display or key, ')')
		end
	end
end

local function osd_append_track_list(name, track_type, tracks)
	osd:append('Available ', name, ' Tracks:')

	local any_selected = false
	for i=1,#tracks do
		any_selected = any_selected or tracks[i].selected
	end

	osd:append(
		'\\N',
		(not any_selected and current == track_type and '' or '{\\alpha&HFF}'),
		osd.RIGHT_ARROW,
		'{\\alpha&H00} ',
		'○', ' ',
		'0: none')

	for i=1,#tracks do
		osd_append_track(tracks[i])
	end
	osd:append('\\N')
end

local function _update()
	mp.unregister_idle(_update)

	local tracks = {
		video={},
		audio={},
		sub={}
	}
	local lines = 3 * 3 -- Available + none + separator
	for _, track in ipairs(mp.get_property_native('track-list')) do
		local list = tracks[track.type]
		list[#list + 1] = track
		lines = lines + 1
	end

	local font_scale = math.min(
		opts.font_scale,
		osd:compute_font_scale(lines)
	)

	osd.data = {
		osd.NBSP, ('\n{\\q2\\fscx%d\\fscy%d}'):format(font_scale * 100, font_scale * 100),
	}

	osd_append_track_list('Video', 'video', tracks.video)
	osd:append('\\N')
	osd_append_track_list('Audio', 'audio', tracks.audio)
	osd:append('\\N')
	osd_append_track_list('Subtitle', 'sub', tracks.sub)

	osd:append(mode:get_ass_help())

	osd.data = table.concat(osd.data)
	osd:update()
end
function update()
	mp.unregister_idle(_update)
	mp.register_idle(_update)
end

function update_menu()
	mp.unobserve_property(update)
	mp.unregister_event(update)

	if visible then
		mode:add_key_bindings()
		mp.observe_property('track-list', nil, update)
		mp.observe_property('sub-visibility', nil, update)
		mp.observe_property('mute', nil, update)
		mp.observe_property('video-params', nil, update)
		mp.observe_property('audio-params', nil, update)
		update()
	else
		mode:remove_key_bindings()
		osd:remove()
	end
end

mp.register_script_message('toggle', function()
	visible = not visible
	update_menu()
end)

for i, track_type in ipairs({'video', 'audio', 'sub'}) do
	mp.add_key_binding(track_type:sub(1, 1), 'show-' .. track_type, function()
		current = track_type
		visible = true
		update_menu()
	end)
end

mp.add_key_binding('t', 'show-tracks', function()
	for i, track in ipairs(mp.get_property_native('track-list')) do
		if not current then
			current = track.type
		end
	end

	visible = true
	update_menu()
end)
