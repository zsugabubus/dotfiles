return function(opts)
	local object = opts.args
	if object == '' then
		object = '@'
	end
	vim.cmd.edit(vim.fn.fnameescape('git://' .. object))
end
