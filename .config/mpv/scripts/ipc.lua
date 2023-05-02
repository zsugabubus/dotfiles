if (
	mp.get_property_native('input-ipc-server') == '' and
	mp.get_property_native('input-ipc-client') == ''
) then
	local options = {
		name = '',
	}
	require 'mp.options'.read_options(options)

	local pid = require 'mp.utils'.getpid()
	local path = ('/tmp/mpv%s%s'):format(options.name, pid)
	mp.msg.info('Automatic server:', path)
	mp.set_property_native('input-ipc-server', path)
end
