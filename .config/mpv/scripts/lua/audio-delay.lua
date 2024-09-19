local audio_time

mp.observe_property('audio-delay', 'native', function()
	audio_time = nil
end)

mp.register_script_message('audio-delay', function()
	local time = mp.get_property_native('time-pos')

	if not audio_time then
		audio_time = time
		mp.osd_message('A-V delay: Audio set')
		return
	end

	mp.commandv('osd-msg-bar', 'set', 'audio-delay', time - audio_time)
end)
