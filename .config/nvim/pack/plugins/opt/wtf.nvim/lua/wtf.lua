local sfind = string.find
local sgsub = string.gsub
local sformat = string.format

local function set_search(flags)
	local till = sfind(flags, 't')
	local forward = not sfind(flags, 'b')

	local ok, char = pcall(vim.fn.getcharstr)
	if not ok then
		return
	end

	vim.fn.setcharsearch({
		forward = forward and 1 or 0,
		['until'] = till and 1 or 0,
		char = char,
	})
end

local function repeat_search(flags)
	local forward = not sfind(flags, 'b')

	local state = vim.fn.getcharsearch()
	local forward = (state.forward == 1) == forward
	local till = state['until'] == 1
	local char = state.char

	local flags = 'W' .. (forward and '' or 'b')

	local pattern = sformat([[\V%s\v]], sgsub(state.char, '\\', '\\\\'))
	if sfind(state.char, '[a-z]') then
		pattern =
			sformat([[\v\c(<%s|[_0-9]@<=%s|\u@=%s)]], pattern, pattern, pattern)
	end

	if till then
		if forward then
			pattern = '\\_.' .. pattern
		else
			pattern = pattern .. '\\zs'
		end
	end

	if forward and vim.api.nvim_get_mode().mode == 'no' then
		vim.cmd.normal({ bang = true, args = { 'v' } })
	end

	for _ = 1, vim.v.count1 do
		vim.fn.search(pattern, flags)
	end
end

return {
	set_search = set_search,
	repeat_search = repeat_search,
}
