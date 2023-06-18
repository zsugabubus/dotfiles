local M = {}

function M.canonical(rev)
	return string.gsub(rev, '[~^][~^0-9]*', function(s)
		local r = ''
		local a, an
		for b, bn in string.gmatch(s, '([~^])(%d*)') do
			local bn = tonumber(bn) or 1
			if b == '~' and bn == 0 then
				-- Ignore.
			elseif a == '~' and b == '~' then
				an = an + bn
			elseif (a == '^' and an == 1) and b == '~' then
				a, an = '~', bn + 1
			elseif a == '~' and (b == '^' and bn == 1) then
				an = an + 1
			else
				if a then
					r = r .. a .. an
				end
				a, an = b, bn
			end
		end
		if a then
			r = r .. a .. an
		end
		return r
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
