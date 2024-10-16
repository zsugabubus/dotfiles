local function is_filetype_matches(pattern, filetype)
	for _, s in ipairs(type(pattern) == 'table' and pattern or { pattern }) do
		if filetype:find(s) then
			return true
		end
	end
	return false
end

local function is_group_matches(group, filetype)
	return (not group.filetype or is_filetype_matches(group.filetype, filetype))
		and (not group.cond or group.cond(filetype))
end

local function new(opts)
	return require('snippets.cache').make_filetype_cache(function(filetype)
		local snippets = {}

		for _, group in ipairs(opts) do
			if is_group_matches(group, filetype) then
				for _, snippet in ipairs(group) do
					table.insert(snippets, snippet)
				end
			end
		end

		return snippets
	end)
end

return {
	new = new,
}
