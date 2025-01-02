local M = {}

function M.canonical(rev)
	return rev
		:gsub('~(%d+)', function(n)
			return ('~'):rep(n)
		end)
		:gsub('%^%d*', function(s)
			return (s == '^' or s == '^1') and '~' or s
		end)
		:gsub('~+', function(s)
			return s == '~' and '~' or ('~' .. #s)
		end)
end

function M.split_path(rev)
	return rev:match('^(:?[^:]*):?(.-)/?$')
end

function M.join(base, rev)
	if rev:find('^refs/') or rev:find('^%x%x%x%x%x*$') then
		return rev
	end

	local base_rev, base_path = M.split_path(base)

	if base_path ~= '' then
		base_path = base_path .. '/' .. rev
	else
		base_path = rev
	end

	return ('%s:%s'):format(base_rev, base_path)
end

function M.parent_tree(rev, nth)
	for _ = 1, nth do
		rev = rev:match('^(:?[^:]*:.-)[^/]-/?$')
		if not rev then
			return
		end
	end
	return rev
end

function M.suffix(rev, suffix)
	local rev, rest = rev:match('^(:?[^:]*)(.*)$')
	return M.canonical(rev .. suffix) .. rest
end

function M.parent_commit(rev, nth)
	return M.suffix(rev, '^' .. nth)
end

function M.ancestor(rev, nth)
	return M.suffix(rev, '~' .. nth)
end

return M
