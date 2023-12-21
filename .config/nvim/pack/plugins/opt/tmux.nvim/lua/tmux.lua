local api, cmd, fn = vim.api, vim.cmd, vim.fn

local function filter_completions(needle, choices)
	return vim.tbl_filter(function(x)
		return string.find(x, needle, 1, true)
	end, choices)
end

local function complete_buffers(prefix)
	return filter_completions(
		prefix,
		fn.systemlist({ 'tmux', 'list-buffers', '-F', '#{buffer_name}' })
	)
end

local function complete_panes(prefix)
	return filter_completions(
		prefix,
		fn.systemlist({
			'tmux',
			'list-panes',
			'-aF',
			'#{session_name}:#{window_index}.#{pane_index}',
		})
	)
end

local function get_target(opts)
	return opts.args == '' and '{last}' or opts.args
end

local function buf_read_system(buf, args)
	api.nvim_buf_set_lines(buf, 0, -1, true, fn.systemlist(args))
end

local function echo(...)
	api.nvim_echo({ { string.format(...), 'Normal' } }, true, {})
end

local function echo_error(...)
	api.nvim_echo({ { string.format(...), 'ErrorMsg' } }, true, {})
end

return {
	BufReadCmd_buffers = function(opts)
		buf_read_system(opts.buf, {
			'tmux',
			'list-buffers',
			'-F',
			'tmux://buffer/#{buffer_name}\t#{buffer_sample}',
		})
		local bo = vim.bo[opts.buf]
		bo.buftype = 'nofile'
		bo.filetype = 'tmuxbuffers'
		bo.readonly = true
		bo.swapfile = false
		api.nvim_buf_set_keymap(opts.buf, 'n', '<CR>', 'gf', {})
	end,
	BufReadCmd_buffer = function(opts)
		local buffer_name = string.sub(opts.match, 15)
		-- Workaround to avoid non-existent buffers show "no buffer X".
		buf_read_system(
			opts.buf,
			'tmux 2>/dev/null show-buffer -b ' .. fn.shellescape(buffer_name)
		)
		vim.bo[opts.buf].buftype = 'acwrite'
	end,
	BufWriteCmd_buffer = function(opts)
		local buffer_name = string.sub(opts.match, 15)
		local output = fn.system({
			'tmux',
			'list-buffers',
			'-f',
			string.format(
				'#{==:#{buffer_name},%s}',
				string.gsub(buffer_name, '[#}]', '\\%0')
			),
			'-F',
			'found',
			';',
			'load-buffer',
			'-b',
			buffer_name,
			'-',
		}, opts.buf)
		if vim.v.shell_error == 0 then
			vim.bo[opts.buf].modified = false
			echo(
				'"%s"%s written',
				buffer_name,
				output == 'found\n' and '' or ' [New]'
			)
		else
			echo_error("Can't write tmux buffer: %s", vim.trim(output))
		end
	end,
	BufReadCmd_pane = function(opts)
		local target = string.sub(opts.match, 13)
		buf_read_system(opts.buf, { 'tmux', 'capture-pane', '-S-', '-pJt', target })
		local bo = vim.bo[opts.buf]
		bo.buftype = 'nofile'
		bo.readonly = true
		bo.swapfile = false
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
		cmd.edit(fn.fnameescape('tmux://buffer/' .. opts.args))
	end,
	Tbuffer_complete = complete_buffers,
	Tlistbuffers = function()
		cmd.edit('tmux://buffers')
	end,
	Tcapture = function(opts)
		cmd.edit(fn.fnameescape('tmux://pane/' .. get_target(opts)))
	end,
	Tcapture_complete = complete_panes,
	Ttermcapture = function(opts)
		fn.termopen({ 'tmux', 'capture-pane', '-S-', '-pet', get_target(opts) })
	end,
	Ttermcapture_complete = complete_panes,
	Tfileyank = function()
		fn.system({
			'tmux',
			'set-buffer',
			'-b',
			'nvim-tmux',
			'--',
			fn.expand(vim.bo.buftype == '' and '%:p' or '%'),
		})
	end,
	Tloadbuffer = function(opts)
		local output = fn.system(opts.args == '' and {
			'tmux',
			'load-buffer',
			'-',
		} or {
			'tmux',
			'load-buffer',
			'-b',
			opts.args,
			'-',
		}, api.nvim_get_current_buf())
		if vim.v.shell_error == 0 then
			echo('Buffer written')
		else
			echo_error("Can't load buffer: %s", vim.trim(output))
		end
	end,
}
