local PRESETS = {
	-- {brightness, contrast, gamma, saturation}
	{ name='(none)', b=0, c=0,  g=0, s=0 },
	{ name='tv',     b=2, c=3,  g=3, s=3 },
	{ name='movie',  b=0, c=27, g=2, s=11 },
}

function cycle(next)
	local current = {
		b=mp.get_property_number('brightness'),
		c=mp.get_property_number('contrast'),
		g=mp.get_property_number('gamma'),
		s=mp.get_property_number('saturation'),
	}
	local i = 1
	for j, x in pairs(PRESETS) do
		if x.b == current.b and
		   x.c == current.c and
		   x.g == current.g and
		   x.s == current.s then
			i = j + (next and 1 or -1)
			break
		end
	end

	local new = PRESETS[(i - 1 + #PRESETS) % #PRESETS + 1]
	mp.set_property_number('brightness', new.b)
	mp.set_property_number('contrast', new.c)
	mp.set_property_number('gamma', new.g)
	mp.set_property_number('saturation', new.s)
	mp.osd_message(('Color preset: %s'):format(new.name))
end

mp.register_script_message('cycle-next', function() cycle(true) end)
mp.register_script_message('cycle-prev', function() cycle(false) end)
