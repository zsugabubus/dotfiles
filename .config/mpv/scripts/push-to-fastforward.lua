local options = require('mp.options')

local opts = {
	speed = 2.71828, -- speeeeeeed
}
options.read_options(opts)

local down = false

-- script-binding push-to-fastforward
mp.add_key_binding(nil, 'push-to-fastforward', function(event)
	if event.event == 'down' then
		down = true
	elseif event.event == 'up' then
		down = false
	elseif event.event == 'press' then
		down = not down
	end

	if down then
		mp.set_property_number('speed', opts.speed)
		mp.osd_message(string.format('▶▶ x%.2f', opts.speed))
	else
		mp.set_property_number('speed', 1)
		mp.osd_message('')
	end
end, { complex = true })
