function _VimdentGetIndents(max_lines)
	local vim_call = vim.api.nvim_call_function

	local indents = {}
	local prev_tabs, prev_spaces = 0, 0

	for lnum=1, math.min(vim_call('line', {'$'}), max_lines) do
		local indent = vim_call('indent', {lnum})
		local tabs, spaces = math.floor(indent / 100), indent % 100

		if
			0 < tabs and
			prev_tabs == tabs and
			(prev_spaces == 0 or spaces == 0)
		then
			spaces = 0
		end

		local key = (tabs - prev_tabs) .. ',' .. (spaces - prev_spaces)
		indents[key] = (indents[key] or 0) + 1

		prev_tabs, prev_spaces = tabs, spaces
	end

	return indents
end
