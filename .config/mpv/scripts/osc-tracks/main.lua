local NBSP = '\194\160'
local RIGHT_ARROW = '\226\158\156'

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

local osd = mp.create_osd_overlay('ass-events')
local visible = false
local current = 'video'

local opts = {
	font_scale = 0.9,
}
options.read_options(opts, nil, update)

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

function cycle_track(prop, up)
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

function switch_track(prop, all)
	local tracks = mp.get_property_native('track-list')
	for i=#tracks,1,-1 do
		local track = tracks[i]
		if (all or track.type == current) and track[prop] then
			mp.set_property_number(track.type, track.id)
		end
	end
end

function osd_append(...)
	for _, s in ipairs({...}) do
		osd.data[#osd.data + 1] = s
	end
end

function ass_escape(s)
	local x = s:gsub('[\\{]', '\\%0')
	return x
end

function osd_append_track(track)
	local enabled = track.selected
	if enabled then
		if track.type == 'audio' then
			enabled = not mp.get_property_native('mute')
		elseif track.type == 'sub' then
			enabled = mp.get_property_native('sub-visibility')
		end
	end

	osd_append(
		'\\N',
		(track.selected and current == track.type and '' or '{\\alpha&HFF}'),
		RIGHT_ARROW,
		'{\\alpha&H00}', NBSP,
		(enabled and '●' or '○'), NBSP,
		track.id, ':', NBSP)

	osd_append('[', track.lang or 'und', ']', NBSP)

	if track.title then
		osd_append("'", ass_escape(track.title):gsub(' ', NBSP), "'", NBSP)
	end

	osd_append('(')

	osd_append(track.codec)

	if track['demux-w'] then
		osd_append(NBSP, track['demux-w'], 'x', track['demux-h'])
	elseif track.type == 'video' and track.selected then
		local pars = mp.get_property_native('video-params')
		if pars then
			osd_append(NBSP, pars.w, 'x', pars.h)
		end
	end

	if track['demux-channels'] and 1 ~= track['demux-channels']:find('unknown') then
		osd_append(NBSP, track['demux-channels'])
	else
		local pars = mp.get_property_native('audio-params')
		if track.type == 'audio' and track.selected and pars and pars['hr-channels'] then
			osd_append(NBSP, pars['hr-channels'])
		elseif track['demux-channel-count'] then
			osd_append(NBSP, track['demux-channel-count'], 'ch')
		end
	end

	if track['demux-samplerate'] then
		osd_append(NBSP, track['demux-samplerate'], 'Hz')
	end

	if track['demux-fps'] then
		osd_append(NBSP, math.ceil(track['demux-fps']), 'fps')
	end

	if track['demux-rotation'] then
		osd_append(NBSP, track['demux-rotation'], 'deg')
	end

	osd_append(')')

	for _, flag in ipairs(TRACK_FLAGS) do
		local key, display = table.unpack(flag)
		if track[key] then
			osd_append(NBSP, '(', display or key, ')')
		end
	end
end

function osd_append_track_list(name, track_type, tracks)
	osd_append('Available', NBSP, name, NBSP, 'Tracks:')

	local any_selected = false
	for i=1,#tracks do
		any_selected = any_selected or tracks[i].selected
	end

	osd_append(
		'\\N',
		(not any_selected and current == track_type and '' or '{\\alpha&HFF}'),
		RIGHT_ARROW,
		'{\\alpha&H00}', NBSP,
		'○', NBSP,
		'0:', NBSP, 'none')

	for i=1,#tracks do
		osd_append_track(tracks[i])
	end
	osd_append('\\N')
end

function update()
	mp.unregister_idle(_update)
	mp.register_idle(_update)
end
function _update()
	mp.unregister_idle(_update)

	local tracks = {
		video={},
		audio={},
		sub={}
	}
	for _, track in ipairs(mp.get_property_native('track-list')) do
		local list = tracks[track.type]
		list[#list + 1] = track
	end

	osd.data = {
		NBSP .. '\n',
		('{\\fscx%d\\fscy%d}'):format(opts.font_scale * 100, opts.font_scale * 100),
	}

	osd_append_track_list('Video', 'video', tracks.video)
	osd_append('\\N')
	osd_append_track_list('Audio', 'audio', tracks.audio)
	osd_append('\\N')
	osd_append_track_list('Subtitle', 'sub', tracks.sub)

	osd_append(mode:get_ass_help())

	osd.data = table.concat(osd.data)
	osd:update()
end

function update_menu()
	mp.unobserve_property(update)

	if visible then
		mode:add_key_bindings()
		mp.observe_property('track-list', nil, update)
		mp.observe_property('sub-visibility', nil, update)
		mp.observe_property('mute', nil, update)
		mp.observe_property('audio-params', nil, update)
		mp.observe_property('video-params', nil, update)
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
		if not current or track.type == 'video' then
			current = track.type
		end
	end

	visible = true
	update_menu()
end)
