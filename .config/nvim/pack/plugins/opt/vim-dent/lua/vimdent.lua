function _VimdentGetIndents(max_lines)
	local indents = {}

	local prev_tabs, prev_spaces = 0, 0

	for lnum=1,math.min(vim.api.nvim_call_function('line', {'$'}), max_lines) do
		local indent = vim.api.nvim_call_function('indent', {lnum})
		local tabs, spaces = math.floor(indent / 100), indent % 100
		local key = (tabs - prev_tabs) .. ',' .. (spaces - prev_spaces)
		indents[key] = (indents[key] or 0) + 1
		prev_tabs, prev_spaces = tabs, spaces
	end

	return indents
end
