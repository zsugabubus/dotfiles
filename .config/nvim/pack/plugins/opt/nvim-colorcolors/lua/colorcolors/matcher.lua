local ffi = require 'ffi'

local M = {}
M.__index = M

function M:new(o)
	o = o or {}
	o.root = {}
	o.accept_vals = {}
	setmetatable(o, self)
	return o
end

-- Get a literal char pattern starting from node (defaults to root).
function M:C(node, c)
	assert(type(c) == 'string')
	node = node or self.root
	if self.ignore_case then
		c = string.lower(c)
	end
	if not node[c] then
		node[c] = {
			-- propagate_A(node).
			_accept = node._accept,
			_offset = node._offset and (node._offset - 1),
		}
	end
	node = node[c]
	return node
end

-- Convenient wrapper around C() for strings.
function M:S(node, s)
	node = node or self.root
	for i = 1, #s do
		node = self:C(node, string.sub(s, i, i))
	end
	return node
end

-- Get a character range pattern starting from node (defaults to root).
function M:R(node, ...)
	node = node or self.root
	local child
	local n = select('#', ...)
	local i = 1
	while i < n do
		local lo, hi = select(i, ...), select(i + 1, ...)
		if type(lo) == 'string' then
			lo, hi = string.byte(lo), string.byte(hi)
		end
		if lo <= hi then
			if not child then
				child = self:C(node, string.char(lo))
				lo = lo + 1
			end
			for c = lo, hi do
				node[string.char(c)] = child
			end
		end
		i = i + 2
	end
	return child
end

-- Convenient wrapper around R(). pat uses syntax of regexp's
-- character classes (e.g. "abd-f0-9").
function M:P(node, pat)
	local args = {} --      @_/`
		--
		--                       Y
		--                       |
		--                      / \
	pat = string.gsub(pat, '(.)-(.)', function(lo, hi)
		--                     \   /
		--                    \( o )/
		--                     | ' |
		--                     / ' \
		--                   \(  O  )/
		--                     \ ' /
		--                      / \
		--                      |'|
		--                      //
		--                      \'\
		--                       \\
		--                        `
		args[#args + 1] = lo
		args[#args + 1] = hi
		return ''
	end)
	--                               _
	--                             /`x`\
	--                \ /          \xXx/
	string.gsub(pat, '(.)', function(c)
		--        .####/ y             |   o
		--          /\  \              A  /`\o
		args[#args + 1] = c
		args[#args + 1] = c
		return ''
	end)
	return self:R(node, unpack(args))
end

function M:NP(node, n, pat)
	if n == 0 then
		return
	end
	for i = 1, n do
		node = self:P(node, pat)
	end
	return node
end

-- Accept node with value.
function M:A(node, val)
	-- Non-compiled version could pass values as-is, however compiled variation
	-- needs to use indices and pass real values side-channel.
	if true then
		self.accept_vals[#self.accept_vals + 1] = val
		val = #self.accept_vals
	end

	local function propagate_A(node, offset)
		if node._offset and offset < node._offset then
			return
		end
		node._offset = offset
		node._accept = val
		for key, child in pairs(node) do
			if #key == 1 then
				propagate_A(child, offset - 1, val)
			end
		end
	end

	assert((node._offset or -1) ~= 0, 'node already accepted')
	propagate_A(node, 0)
end

function M:build()
	local id = 0
	local charset = {}

	local function compute_other(origin, path)
		local i, node = 2, self.root
		while i <= #path do
			local match = node[string.sub(path, i, i)]
			if match then
				i, node = i + 1, match
			elseif node._other then
				node = node._other
			else
				i, node = i + 1, self.root
			end
		end
		return node
	end

	local tq_head = {_next=nil}
	local tq_last = tq_head

	local function prepare(d, node, path)
		if node._id then
			return
		end
		if node ~= self.root then
			node._other = compute_other(node, path)
			assert(node._other ~= node)
		end
		id = id + 1
		node._id = id
		-- Assign it before so it does not interfere with pairs().
		node._next = node

		tq_last._next, tq_last = node, node

		for key, child in pairs(node) do
			if #key == 1 then
				local c = key
				charset[c] = (charset[c] or 0) + 1
				prepare(d + 1, child, path .. c)
			end
		end
	end
	prepare(0, self.root, '')

	-- Map input byte -> internal representation.
	--
	-- - Form equivalence classes to avoid excessive branching.
	--   Continouos ranges could be handled by the compiler using lower <= x <=
	--   upper logic but for example X == a and X == A like stuff requires extra
	--   comparsions. => X == aA
	--
	-- - Dense pack (in case LuaJIT wants to use jump tables).
	local m = ffi.new("uint8_t[?]", 257)
	local eof
	do
		local cs = {}
		for c, k in pairs(charset) do
			cs[#cs + 1] = c
		end
		table.sort(cs, function(x, y) return x < y end)
		ffi.fill(m, 256, #cs)
		for i, c in ipairs(cs) do
			m[string.byte(c)] = i - 1
			if self.ignore_case then
				m[string.byte(string.upper(c))] = i - 1
			end
		end
		eof = #cs + 1
		m[256] = eof
	end

	local code = {}
	local function emit(fmt, ...)
		code[#code + 1] = string.format(fmt, ...)
	end

	emit('local m,v=...;')
	emit('local b,t=string.byte,bit.tobit;')
	emit('local f;f={')

	-- Generate a huge table of f_X(input, index) transition function for
	-- every node. Functions are subject to tail call optimization so we
	-- are not in the danger of stack overflow.
	--
	-- PERF: Using functions is actually 2-3x faster than labels.
	local function nodegen(node)
		emit('function(s,i,a)')

		local children = {}
		local empty = true
		for key, child in pairs(node) do
			if #key == 1 then
				empty = false
				children[child._id] = children[child._id] or {}
				local r = children[child._id]
				r[#r + 1] = m[string.byte(key)]
			end
		end

		if not empty then
			-- PERF: Parenthesis around (b()) probably force a single return.
			-- PERF: Outer t() to probably handle c as an integer.
			emit('local c=t(m[(b(s,i))or 256])')
		end

		for child_id, keys in pairs(children) do
			table.sort(keys)
			emit('if ')
			-- Do not rely on Lua optimizer. Do it by hand.
			local i = 1
			while i <= #keys do
				if i ~= 1 then
					emit(' or ')
				end
				if keys[i] + 1 == keys[i + 1] then
					-- 0 <= X is always true, unnecessary to check.
					if 0 < keys[i] then
						emit('%d<=c and ', keys[i])
					end
					repeat
						i = i + 1
					until keys[i] + 1 ~= keys[i + 1]
					emit('c<=%d', keys[i])
				else
					emit('c==%d', keys[i])
				end
				i = i + 1
			end
			emit(' then return f[%d](s,i+1,a)end;', child_id)
		end

		if node._accept ~= nil then
			emit(
				'i=a(s,i%s,v[%d])or i;',
				node._offset ~= 0 and '+' .. node._offset or '',
				node._accept
			)
		end

		if
			node._other and
			-- Report the longer match only that ends here.
			-- yellowgreen|
			--       green|
			not (node._accept ~= nil and node._offset == 0)
		then
			emit('return f[%d](s,i,a)', node._other._id)
		else
			-- Other states will run into the _other branch so it is enough
			-- to check EOF at the root node.
			if node == self.root then
				emit('if c==%d then return end;', eof)
			end
			emit(
				'return f[%d](s,i%s,a)',
				self.root._id,
				node._accept == nil and '+1' or ''
			)
		end
		emit('end,')
	end

	tq_head = tq_head._next
	while tq_head do
		nodegen(tq_head)
		tq_head, tq_head._next = tq_head._next, nil
	end

	-- _G.a = vim.inspect(self.root)

	emit('}')
	emit('return f')

	code = table.concat(code)
	local f_root = loadstring(code)(m, self.accept_vals)[self.root._id]

	--[[ print('got', f_root(
		'blue YelloW greenavy grenavy yellowgreen darkyelloween Orange yellowgrn reDSlategrey',
		1,
		function(s, i, d)
			print("accept", i, d.len, d.r, d.g, d.b)
		end
	)) ]]

	return f_root
end

return M
