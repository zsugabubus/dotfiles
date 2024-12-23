local named_dirs

local function get_zsh_named_dirs(t)
	local lines = vim.fn.systemlist({
		'zsh',
		'-ic',
		[[printf 'TILDE.NVIM:%s%s\n' "${(@kv)nameddirs}"]],
	})
	for _, line in ipairs(lines) do
		local name, path = line:match('^TILDE%.NVIM:([^/]*)(.*)')
		if name then
			t[name] = vim.fn.fnamemodify(path, ':~')
		end
	end
end

local function get_named_dirs()
	local t = {}
	get_zsh_named_dirs(t)
	return t
end

local function expand_named_dir(name)
	if not named_dirs then
		named_dirs = get_named_dirs()
	end
	return named_dirs[name]
end

local function expand_cmdline(partial)
	local event = vim.v.event

	if event.cmdtype ~= ':' or event.cmdlevel ~= 1 or event.abort then
		return
	end

	local cmdline = vim.fn.getcmdline()
	local pat = partial and '[/ ]' or ''
	local before, name, after =
		cmdline:match('^( *[a-zA-Z0-9]+ +)~([a-zA-Z0-9]+)(' .. pat .. '.*)')

	if not name then
		return
	end

	local expanded_path = expand_named_dir(name)

	if not expanded_path then
		return
	end

	vim.fn.setcmdline(
		('%s%s%s'):format(before, vim.fn.fnameescape(expanded_path), after)
	)
end

local function handle_cmdline_leave()
	expand_cmdline(false)
end

local function handle_cmdline_changed()
	expand_cmdline(true)
end

return {
	_handle_cmdline_leave = handle_cmdline_leave,
	_handle_cmdline_changed = handle_cmdline_changed,
}
