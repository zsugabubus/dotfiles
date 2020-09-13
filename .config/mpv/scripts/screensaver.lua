function state_changed()
	mp.set_property_bool('stop-screensaver',
		(
			not mp.get_property_bool('pause')
		and
			(mp.get_property_number('estimated-frame-count') or 0) > 1
		)
		or
			mp.get_property_bool('fullscreen'))
end

mp.observe_property('pause', nil, state_changed);
mp.observe_property('estimated-frame-count', nil, state_changed);
mp.observe_property('fullscreen', nil, state_changed);
