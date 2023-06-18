return function(opts)
	if opts.args == '' then
		opts.args = '@'
	end
	vim.cmd.edit('git://' .. opts.args)
end
