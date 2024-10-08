local api = vim.api
local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn

local buf_user_command = api.nvim_buf_create_user_command
local buf_keymap = api.nvim_buf_set_keymap

local function filter_completions(list, s)
	if s == '' then
		return list
	end
	return fn.matchfuzzy(list, s)
end

local function complete_buffers(prefix)
	return filter_completions(
		fn.systemlist({ 'tmux', 'list-buffers', '-F', '#{buffer_name}' }),
		prefix
	)
end

local function complete_panes(prefix)
	local t = fn.systemlist({
		'tmux',
		'list-panes',
		'-aF',
		'#{session_name}:#{window_index}.#{pane_index}\n'
			.. '#{window_id}.#{pane_index}\n'
			.. '#{pane_id}',
	})
	table.insert(t, '{last}')
	table.insert(t, '!')
	return filter_completions(t, prefix)
end

local function log(s)
	api.nvim_echo({ { s, 'Normal' } }, true, {})
end

local function log_error(s)
	api.nvim_echo({ { s, 'ErrorMsg' } }, true, {})
end

local function read_system(args, silent)
	local lines = fn.systemlist(args)
	if vim.v.shell_error == 0 then
		api.nvim_buf_set_lines(0, 0, -1, true, lines)
	elseif not silent then
		log_error('tmux: ' .. vim.trim(table.concat(lines, '\n')))
	end
end

local function display_message(target, format)
	return fn.systemlist({ 'tmux', 'display-message', '-t', target, '-p', format })[1]
end

local function get_pane_id(target)
	return display_message(target, '#{pane_id}')
end

local function get_pid(target)
	return tonumber(display_message(target, '#{pane_pid}'))
end

local function get_cwd(target)
	return vim.uv.fs_readlink(string.format('/proc/%d/cwd', get_pid(target)))
end

return {
	BufReadCmd_buffers = function(opts)
		local buffer_name = string.sub(opts.match, 16)
		bo.swapfile = false
		if buffer_name == '' then
			read_system({
				'tmux',
				'list-buffers',
				'-F',
				'tmux://buffers/#{buffer_name}\t#{buffer_sample}',
			})
			bo.buftype = 'nofile'
			bo.filetype = 'tmuxlist'
			bo.readonly = true
			bo.modeline = false
			buf_keymap(0, 'n', '<CR>', 'gf', {})
		else
			read_system({ 'tmux', 'show-buffer', '-b', buffer_name }, true)
			bo.buftype = 'acwrite'
		end
	end,
	BufWriteCmd_buffers = function(opts)
		local buffer_name = string.sub(opts.match, 16)
		local output = fn.system({
			'tmux',
			'set',
			'-g',
			'@_',
			buffer_name,
			';',
			'list-buffers',
			'-f',
			'#{==:#{buffer_name},#{@_}}',
			'-F',
			'found',
			';',
			'load-buffer',
			'-b',
			buffer_name,
			'-',
			';',
			'set',
			'-gu',
			'@_',
		}, opts.buf)
		if vim.v.shell_error == 0 then
			bo.modified = false
			log(
				string.format(
					'"%s"%s written',
					buffer_name,
					output == 'found\n' and '' or ' [New]'
				)
			)
		else
			log_error("Can't write tmux buffer: " .. vim.trim(output))
		end
	end,
	BufReadCmd_panes = function(opts)
		local target = string.sub(opts.match, 14)
		bo.buftype = 'nofile'
		bo.swapfile = false
		bo.modeline = false
		if target == '' then
			read_system({
				'tmux',
				'list-panes',
				'-aF',
				'tmux://panes/#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_title}',
			})
			bo.filetype = 'tmuxlist'
			api.nvim_buf_set_keymap(0, 'n', '<CR>', 'gf', {})
		else
			local has_AnsiEsc = fn.exists(':AnsiEsc') == 2
			read_system({
				'tmux',
				'capture-pane',
				'-S-',
				'-pJt',
				target,
				has_AnsiEsc and '-e' or nil,
			})
			if has_AnsiEsc then
				cmd.AnsiEsc()
			end
			buf_user_command(0, 'Tcdhere', function()
				cmd.cd(get_cwd(target))
			end, {})
		end
		bo.readonly = true
	end,
	Tsplitwindow = function(opts)
		fn.system({
			'tmux',
			'split-window',
			opts.smods.horizontal and '-h' or '-v',
			'-c',
			fn.getcwd(),
		})
	end,
	Tbuffer = function(opts)
		cmd.edit(fn.fnameescape('tmux://buffers/' .. opts.args))
	end,
	Tbuffer_complete = complete_buffers,
	Tbuffers = function()
		cmd.edit('tmux://buffers/')
	end,
	Tpane = function(opts)
		local target = opts.fargs[1]
		if opts.bang then
			target = get_pane_id(target) or target
		end
		cmd.edit(fn.fnameescape('tmux://panes/' .. target))
	end,
	Tpane_complete = complete_panes,
	Tpanes = function()
		cmd.edit('tmux://panes/')
	end,
	Twrite = function(opts)
		local buffer_name = opts.fargs[1]
		local output = fn.system(
			buffer_name
					and {
						'tmux',
						'load-buffer',
						'-b',
						buffer_name,
						'-',
					}
				or {
					'tmux',
					'load-buffer',
					'-',
				},
			opts.range == 0 and api.nvim_get_current_buf()
				or api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, {})
		)
		if vim.v.shell_error == 0 then
			log('Buffer written')
		else
			log_error("Can't write buffer: " .. vim.trim(output))
		end
	end,
	Tcd = function(opts)
		cmd.cd(get_cwd(opts.fargs[1]))
	end,
	Tcd_complete = complete_panes,
	get_cwd = get_cwd,
}
