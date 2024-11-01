local buf_set_lines = vim.api.nvim_buf_set_lines
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

local function parse(s)
	return string.match(s, '^(.-) *%%s *(.-)$')
end

local function expand(c)
	if c == '*' or c == '/' or c == '-' then
		return '%' .. c .. '*'
	end
	return ''
end

local function left(lnum, n)
	vim.cmd(lnum .. 'left' .. n)
end

local function comment_lines(buf, start_row, end_row, op)
	local l_part, r_part = parse(get_commentstring(buf, start_row))

	local pattern = '^%s-()'
		.. vim.pesc(l_part)
		.. expand(string.sub(l_part, -1))
		.. ' ?()'
	if r_part ~= '' then
		pattern = pattern
			.. '.-() ?'
			.. expand(string.sub(r_part, 1, 1))
			.. vim.pesc(r_part)
			.. '()'
	end

	local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row, true)
	local indents = {}

	local indent
	for i, line in ipairs(lines) do
		if string.find(line, '%S') then
			indents[i] = vim.fn.indent(start_row + i)
			indent = math.min(indent or math.huge, indents[i])
		end
	end

	local bo = vim.bo[buf]
	local use_tabs = indent
		and not bo.expandtab
		and bo.vartabstop == ''
		and (bo.shiftwidth == 0 or bo.shiftwidth == bo.tabstop)
		and (indent % bo.tabstop) == 0

	for i, line in ipairs(lines) do
		local row = start_row + i - 1
		local l_start, l_end, r_start, r_end = string.match(line, pattern)

		if op ~= true and l_start then
			op = false
			if l_end == #line + 1 or (l_end == r_start and r_end == #line + 1) then
				buf_set_lines(buf, row, row + 1, true, { '' })
			else
				if r_start then
					buf_set_text(buf, row, r_start - 1, row, r_end - 1, {})
				end
				buf_set_text(buf, row, l_start - 1, row, l_end - 1, {})
				left(row + 1, vim.fn.indent(row + 1))
			end
		elseif op ~= false and indents[i] then
			op = true
			if r_part ~= '' then
				buf_set_text(buf, row, #line, row, #line, { ' ' .. r_part })
			end
			if use_tabs then
				left(row + 1, indents[i] - indent)
				buf_set_text(buf, row, 0, row, 0, { l_part .. ' ' })
			else
				buf_set_text(buf, row, 0, row, string.find(line, '%S') - 1, {
					l_part .. string.rep(' ', indents[i] - indent + 1),
				})
			end
			left(row + 1, indent)
		elseif op == true then
			buf_set_lines(buf, row, row + 1, true, { l_part .. r_part })
			if indent then
				left(row + 1, indent)
			end
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

local function get_comment_range(buf, row)
	local l_part, r_part = parse(get_commentstring(buf, row))
	local pattern = '^%s*' .. vim.pesc(l_part) .. '.*' .. vim.pesc(r_part) .. '$'

	local function is_commented(row)
		local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
		return line and string.find(line, pattern)
	end

	if not is_commented(row) then
		return
	end

	local start_row = row
	while is_commented(start_row - 1) do
		start_row = start_row - 1
	end

	local end_row = row
	while is_commented(end_row + 1) do
		end_row = end_row + 1
	end

	return start_row, end_row
end

return {
	comment_lines = comment_lines,
	get_comment_range = get_comment_range,
	get_buf_commentstring = get_buf_commentstring,
	get_treesitter_commentstring = get_treesitter_commentstring,
}
