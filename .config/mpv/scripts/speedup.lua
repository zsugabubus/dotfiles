local options = require('mp.options')
local msg = require('mp.msg')

local opts = {
	speed = 2.71828 -- speeeeeeed
}
options.read_options(opts)

mp.add_key_binding('F', 'speedup', function(t)
	if t.event == 'up' then
		mp.set_property_number('speed', 1)
		mp.osd_message('')
	else
		mp.set_property_number('speed', opts.speed)
		mp.osd_message(('▶▶ x%.2f'):format(opts.speed), 999)
	end
end, {complex=true})
