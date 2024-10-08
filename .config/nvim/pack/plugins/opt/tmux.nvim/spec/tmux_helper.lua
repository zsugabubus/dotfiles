local function create_tmux()
	local socket_path = vim.fn.tempname() .. '-tmux'

	local function tmux(...)
		local output = vim.fn.systemlist({ 'tmux', '-S', socket_path, ... })
		if vim.v.shell_error ~= 0 then
			return error(table.concat(output, '\n'))
		end
		return output
	end

	local function exec(...)
		return tmux('-N', '--', ...)
	end

	return {
		start_server = function()
			tmux(
				'-f',
				'/dev/null',
				'start-server',
				';',
				'set',
				'-g',
				'exit-empty',
				'off',
				';',
				'set',
				'-g',
				'remain-on-exit',
				'on'
			)
		end,
		kill_server = function()
			exec('kill-server')
		end,
		get_env = function()
			return socket_path
		end,
		get_buffer_lines = function(buffer_name)
			return exec('show-buffer', '-b', buffer_name)
		end,
		set_buffer = function(buffer_name, data)
			assert(#data > 0)
			exec('set-buffer', '-b', buffer_name, '--', data)
		end,
		list_buffers = function()
			return exec('list-buffers', '-F', '#{buffer_name}')
		end,
		new_session = function(...)
			exec('new-session', '-d', ...)
		end,
		split_window = function(...)
			exec('split-window', ...)
		end,
		new_window = function(...)
			exec('new-window', ...)
		end,
		set_pane_title = function(target, title)
			exec('select-pane', '-t', target, '-T', title)
		end,
		assert_target_exists = function(target)
			exec('clear-history', '-t', target)
		end,
		client = function(...)
			tmux('-N', '-C', '--', ...)
		end,
	}
end

return {
	create_tmux = create_tmux,
}
