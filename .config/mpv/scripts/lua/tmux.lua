mp.register_script_message('tmux', function(keys)
	mp.command_native({
		name = 'subprocess',
		playback_only = false,
		args = {
			'tmux',
			'new-window',
			'-t',
			'home',
			'zsh',
			'-ic',
			string.format('mpt %s', mp.get_property_native('input-ipc-server')),
			';',
			'run-shell',
			'-d',
			'0.1',
			';',
			'send-keys',
			keys,
		},
	})
end, { repeatable = false })
