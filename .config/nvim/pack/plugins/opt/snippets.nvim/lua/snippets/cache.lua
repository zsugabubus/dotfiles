local function make_filetype_cache(get_snippets)
	local buf_cache = {}
	local filetype_cache = {}
	local lang_cache = {}

	local function forget_buffer(opts)
		buf_cache[opts.buf] = nil
		return true
	end

	local function get_filetype_snippets(filetype)
		local snippets = filetype_cache[filetype]

		if snippets then
			return snippets
		end

		snippets = get_snippets(filetype)

		filetype_cache[filetype] = snippets
		return snippets
	end

	local function get_lang_snippets(lang)
		local snippets = lang_cache[lang]

		if snippets then
			return snippets
		end

		local fts = vim.treesitter.language.get_filetypes(lang)

		if #fts == 1 then
			snippets = get_filetype_snippets(fts[1])
		else
			snippets = {}
			table.sort(fts)
			for _, ft in ipairs(fts) do
				for _, snippet in ipairs(get_filetype_snippets(ft)) do
					table.insert(snippets, snippet)
				end
			end
		end

		lang_cache[lang] = snippets
		return snippets
	end

	return function(buf, row)
		assert(buf ~= 0)
		local cache = buf_cache[buf]

		if not cache then
			local has_treesitter, ltree = pcall(vim.treesitter.get_parser, buf)

			cache = {
				ltree = has_treesitter and ltree or nil,
				filetype = vim.bo[buf].filetype,
			}
			buf_cache[buf] = cache

			vim.api.nvim_create_autocmd({ 'BufUnload', 'FileType' }, {
				buffer = buf,
				callback = forget_buffer,
			})
		end

		local ltree = cache.ltree
		if ltree then
			ltree:parse({ row, row + 1 })
			local tree = ltree:language_for_range({ row, 0, row, 0 })
			return get_lang_snippets(tree:lang())
		else
			return get_filetype_snippets(cache.filetype)
		end
	end
end

return {
	make_filetype_cache = make_filetype_cache,
}
