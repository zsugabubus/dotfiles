return function(max_lines)
	local Vcall = vim.api.nvim_call_function

	local indents = {}
	local prev_tabs, prev_spaces = 0, 0

	for lnum=1, math.min(Vcall('line', {'$'}), max_lines) do
		local indent = Vcall('indent', {lnum})
		local tabs, spaces = math.floor(indent / 100), indent % 100

		if
			0 < tabs and
			prev_tabs == tabs and
			(prev_spaces == 0 or spaces == 0)
		then
			spaces = 0
		end

		local d =
			(((tabs == 0) or (prev_tabs == 0)) and '1,' or '0,') ..
			(tabs - prev_tabs) .. ',' ..
			(spaces - prev_spaces)
		indents[d] = (indents[d] or 0) + 1

		prev_tabs, prev_spaces = tabs, spaces
	end

	return indents
end
