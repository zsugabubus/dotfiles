local M = {}

local function expand(c)
	if c == '*' or c == '/' then
		return vim.pesc(c) .. '*'
	end
	return ''
end

function M.comment_lines(start_lnum, end_lnum)
	local cms = vim.bo.commentstring
	if cms == '' then
		cms = '#%s'
	end

	pcall(function()
		local ft = vim.bo.filetype
		local lang = vim.treesitter.language.get_lang(ft) or ft
		local tree = vim.treesitter.get_parser(0, lang)
		tree:parse()
		local ty =
			tree:named_node_for_range({ start_lnum - 1, 0, start_lnum - 1, 0 }):type()

		if string.match(ty, '^jsx_') then
			cms = '{/*%s*/}'
		end
	end)

	local cms_prefix, cms_suffix = string.match(cms, '^(.-) *%%s *(.-)$')

	local lines = vim.api.nvim_buf_get_lines(0, start_lnum - 1, end_lnum, true)

	local pattern = '^(%s-)('
		.. vim.pesc(cms_prefix)
		.. expand(string.sub(cms_prefix, -1))
		.. ' ?)'
	if cms_suffix ~= '' then
		pattern = pattern
			.. '.-( ?'
			.. expand(string.sub(cms_suffix, 1, 1))
			.. vim.pesc(cms_suffix)
			.. ')(.-)$'
	end

	local indent = math.huge
	for _, line in ipairs(lines) do
		indent = math.min(indent, (string.find(line, '%S') or math.huge) - 1)
	end

	local op
	for i, line in ipairs(lines) do
		local lnum = start_lnum + i - 1
		local prefix_offset, prefix, suffix, suffix_offset =
			string.match(line, pattern)

		if op ~= true and prefix then
			op = false
			if suffix then
				vim.api.nvim_buf_set_text(
					0,
					lnum - 1,
					#line - #suffix_offset - #suffix,
					lnum - 1,
					#line - #suffix_offset,
					{}
				)
			end
			vim.api.nvim_buf_set_text(
				0,
				lnum - 1,
				#prefix_offset,
				lnum - 1,
				#prefix_offset + #prefix,
				{}
			)
		elseif op ~= false and string.find(line, '%S') then
			op = true
			if cms_suffix ~= '' then
				vim.api.nvim_buf_set_text(0, lnum - 1, #line, lnum - 1, #line, {
					' ' .. cms_suffix,
				})
			end
			vim.api.nvim_buf_set_text(0, lnum - 1, indent, lnum - 1, indent, {
				cms_prefix .. ' ',
			})
		end
	end

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

return M
