local mpv_hup = os.getenv('XDG_RUNTIME_DIR') .. '/mpv_hup'

local mode = 'pause'
local input_ipc_server
local pause = true
local mute = true
local ignore = true

local function get_currently_playing()
	local f = io.open(mpv_hup)
	if f then
		local s = assert(f:read('*all'))
		assert(f:close())
		return s
	end
end

local function set_currently_playing(s)
	local f = io.open(mpv_hup, 'w')
	if f then
		assert(f:write(s))
		assert(f:close())
	end
end

mp.observe_property('input-ipc-server', 'native', function(_, value)
	input_ipc_server = value
end)

mp.observe_property('pause', 'native', function(_, value)
	pause = value
	if pause then
		mode = 'pause'
	end
	ignore = ignore and (pause or mute)
end)

mp.observe_property('mute', 'native', function(_, value)
	mute = value
	if mute then
		mode = 'mute'
	end
	ignore = ignore and (pause or mute)
end)

local function is_disabled()
	return string.match(mp.get_opt('hup') or '', '^[nNfF0]')
end

local function handle_file_loaded()
	mp.unregister_event(handle_file_loaded)

	mp.observe_property('focused', 'native', function(_, value)
		if not value then
			return
		end

		if ignore or is_disabled() or not mp.get_property_native('audio') then
			return
		end

		local s = get_currently_playing()
		if s == input_ipc_server then
			return
		end

		if pause or mute then
			mp.set_property_native('pause', false)
			mp.set_property_native('mute', false)
			mp.msg.info(
				'Resuming playback. Use script-message nohup or --script-opts=hup=no to disable.'
			)
		end

		if s then
			mp.command_native({
				name = 'subprocess',
				playback_only = false,
				detach = true,
				args = {
					'sh',
					'-c',
					'echo script-message hup | socat - UNIX-CONNECT:$1',
					'sh',
					s,
				},
			})
		end

		set_currently_playing(input_ipc_server)
	end)
end

mp.register_event('file-loaded', handle_file_loaded)

mp.register_script_message('hup', function(arg)
	if arg ~= nil then
		mp.commandv('change-list', 'script-opts', 'set', 'hup=' .. arg)
		mp.msg.info(is_disabled() and 'Hup disabled' or 'Hup enabled')
		return
	end

	if is_disabled() then
		return
	end

	if not pause and not mute then
		mp.set_property_native('pause', mode == 'pause')
		mp.set_property_native('mute', mode == 'mute')
		mp.msg.info(
			'Pausing playback. Use script-message nohup or --script-opts=hup=no to disable.'
		)
	end
end)

mp.register_script_message('nohup', function()
	mp.commandv('script-message', 'hup', 'no')
end)
