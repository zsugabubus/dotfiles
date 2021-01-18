mp.add_hook('on_load_fail', 40, function(hook)
	mp.commandv('playlist-remove', 'current')
end)
