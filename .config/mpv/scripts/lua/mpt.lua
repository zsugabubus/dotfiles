mp.register_script_message('mpt-start-tmux', function(keys)
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
			('mpt %s'):format(mp.get_property_native('input-ipc-server')),
			';',
			'run-shell',
			'-d',
			'0.1',
			';',
			'send-keys',
			keys,
		},
	})

	if os.getenv('DISPLAY') then
		mp.command_native({
			name = 'subprocess',
			playback_only = false,
			detach = true,
			args = {
				'xdotool',
				'search',
				'--onlyvisible',
				'--class',
				'Alacritty',
				'windowactivate',
			},
		})
	end
end)

local function is_mpt_active()
	local n = mp.get_property_native('user-data/mpt/last-activity') or 0
	return n + 1 >= os.time()
end

mp.register_script_message('mpt-if', function(yes, no)
	mp.command(is_mpt_active() and yes or no)
end)
