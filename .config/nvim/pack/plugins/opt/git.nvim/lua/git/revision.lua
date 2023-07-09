local M = {}

function M.canonical(rev)
	return rev
		:gsub('~(%d+)', function(n)
			return string.rep('~', tonumber(n))
		end)
		:gsub('(%^%d*)', function(s)
			return (s == '^' or s == '^1') and '~' or s
		end)
		:gsub('~+', function(s)
			return s == '~' and '~' or ('~' .. #s)
		end)
end

function M.split_path(rev)
	return string.match(rev, '^(:?[^:]*):?(.-)/?$')
end

local REVISION_RE = vim.regex([[\v^\x{4,}$|^refs/]])

function M.join(base, rev)
	if REVISION_RE:match_str(rev) then
		return rev
	else
		local base_rev, base_path = M.split_path(base)

		if base_path ~= '' then
			base_path = base_path .. '/' .. rev
		else
			base_path = rev
		end

		return string.format('%s:%s', base_rev, base_path)
	end
end

function M.parent_tree(rev)
	return string.match(rev, '^(:?[^:]*:.-)[^/]-/?$')
end

function M.suffix(rev, suffix)
	local rev, rest = string.match(rev, '^(:?[^:]*)(.*)$')
	return M.canonical(rev .. suffix) .. rest
end

function M.parent_commit(rev, nth)
	return M.suffix(rev, '^' .. nth)
end

function M.ancestor(rev, nth)
	return M.suffix(rev, '~' .. nth)
end

return M
