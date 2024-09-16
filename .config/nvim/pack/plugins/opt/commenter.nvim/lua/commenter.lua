local buf_set_text = vim.api.nvim_buf_set_text
local config = vim.g.commenter or {}

local function get_buf_commentstring(buf)
	local s = vim.bo[buf].commentstring
	if s == '' then
		return '#%s'
	end
	return s
end

local function get_treesitter_commentstring(buf, row)
	local ok, tree = pcall(vim.treesitter.get_parser, buf)
	if not ok then
		return get_buf_commentstring(buf)
	end

	tree:parse({ row, row + 1 })

	local range = { row, 0, row, 0 }
	local ltree = tree:language_for_range(range)
	local ty = ltree:named_node_for_range(range):type()
	if ty == 'jsx_text' then
		return '{/*%s*/}'
	end

	local ft = vim.bo[buf].filetype
	repeat
		local fts = vim.treesitter.language.get_filetypes(ltree:lang())
		if vim.list_contains(fts, ft) then
			return get_buf_commentstring(buf)
		end

		for _, ft in ipairs(fts) do
			local s = vim.filetype.get_option(ft, 'commentstring')
			if s ~= '' then
				return s
			end
		end

		ltree = ltree:parent()
	until not ltree

	return '#%s'
end

local get_commentstring = config.get_commentstring
	or get_treesitter_commentstring

local function expand(c)
	if c == '*' or c == '/' or c == '-' then
		return '%' .. c .. '*'
	end
	return ''
end

local function comment_lines(buf, start_row, end_row, op)
	local cms = get_commentstring(buf, start_row)
	local cms_prefix, cms_suffix = string.match(cms, '^(.-) *%%s *(.-)$')

	local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row, true)

	local pattern = '^%s-()'
		.. vim.pesc(cms_prefix)
		.. expand(string.sub(cms_prefix, -1))
		.. ' ?()'
	if cms_suffix ~= '' then
		pattern = pattern
			.. '.-() ?'
			.. expand(string.sub(cms_suffix, 1, 1))
			.. vim.pesc(cms_suffix)
			.. '()'
	end

	local indent = math.huge
	for _, line in ipairs(lines) do
		indent = math.min(indent, (string.find(line, '%S') or math.huge) - 1)
	end

	for i, line in ipairs(lines) do
		local row = start_row + i - 1
		local prefix_start, prefix_end, suffix_start, suffix_end =
			string.match(line, pattern)

		if op ~= true and prefix_start then
			op = false
			if suffix_start then
				buf_set_text(buf, row, suffix_start - 1, row, suffix_end - 1, {})
			end
			buf_set_text(buf, row, prefix_start - 1, row, prefix_end - 1, {})
		elseif op ~= false and string.find(line, '%S') then
			op = true
			if cms_suffix ~= '' then
				buf_set_text(buf, row, #line, row, #line, { ' ' .. cms_suffix })
			end
			buf_set_text(buf, row, indent, row, indent, { cms_prefix .. ' ' })
		end
	end

	if op == nil or #lines > vim.go.report then
		vim.api.nvim_echo({
			{
				op ~= nil and string.format(
					'%d %s %s',
					#lines,
					#lines == 1 and 'line' or 'lines',
					op and 'commented' or 'uncommented'
				) or '--No lines to comment--',
				'Normal',
			},
		}, false, {})
	end
end

return {
	comment_lines = comment_lines,
	get_buf_commentstring = get_buf_commentstring,
	get_treesitter_commentstring = get_treesitter_commentstring,
}
