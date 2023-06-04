local M = {}
M.__index = M

local function shift(s)
	do
		local _, _, head, n, tail = string.find(s, '^%[([^]]*)]{(%d+)}(.*)')
		if head then
			n = n - 1
			assert(0 <= n)
			if 0 < n then
				return head, string.format('[%s]{%d}%s', head, n, tail)
			else
				return head, tail
			end
		end
	end
	do
		local _, _, head, tail = string.find(s, '^%[([^]]*)](.*)')
		if head then
			return head, tail
		end
	end
	if 1 <= #s then
		return string.sub(s, 1, 1), string.sub(s, 2)
	end
end

local function expand(cc)
	local ret = {} --      @_/`
	--
	--                       Y
	--                       |
	--                      / \
	cc = string.gsub(cc, '(.)-(.)', function(lo, hi)
		--                   \   /
		--                  \( o )/
		--                   | ' |
		--                   / ' \
		--                 \(  O  )/
		--                   \ ' /
		--                    / \
		--                    |'|
		--                    //
		--                    \'\
		--                     \\
		--                      `
		for c = string.byte(lo), string.byte(hi) do
			ret[#ret + 1] = string.char(c)
		end
		return ''
	end)
	--                              _
	--                            /`x`\
	--               \ /          \xXx/
	string.gsub(cc, '(.)', function(c)
		--        .####/ y            |   o
		--         /\  \              A  /`\o
		ret[#ret + 1] = c
	end)
	return ret
end

local function sorted_keys(t)
	local sorted = {}
	for key in pairs(t) do
		sorted[#sorted + 1] = key
	end
	table.sort(sorted)
	return sorted
end

function M:new(opts)
	local ffi = require 'ffi'
	local nodes = {}
	local charset = {}
	local id = 0
	local accepts = {}

	local function serialize(x)
		-- What is not easier.
		return vim.inspect(x)
	end

	local function generate(spec, path)
		local node = {}
		local branches = {}

		for _, pat in pairs(spec) do
			local head, tail = shift(pat[1])
			if head then
				for _, c in ipairs(expand(head)) do
					if opts.ignore_case then
						c = string.lower(c)
					end
					branches[c] = branches[c] or {}
					if not charset[c] then
						charset[c] = true
					end
					table.insert(branches[c], {tail, pat[2]})
				end
			else
				node.accept = pat[2]
			end
		end

		branches.accept = node.accept

		local key = serialize(branches)
		local found = nodes[key]
		if found then
			return found
		end
		nodes[key] = node

		branches.accept = nil

		node.id = id
		node.path = path
		accepts[id] = node.accept
		id = id + 1

		for c, branch in pairs(branches) do
			node[c] = generate(branch, path .. c)
		end
		return node
	end

	local start = generate(opts.spec, '')

	local charmap = ffi.new('uint8_t[?]', 256)
	local k = 0
	do
		ffi.fill(charmap, 256, 0xff)

		for _, c in ipairs(sorted_keys(charset)) do
			c = string.byte(c)
			if charmap[c] == 0xff then
				if opts.ignore_case then
					charmap[string.byte(string.upper(string.char(c)))] = k
				end
				charmap[c] = k
				k = k + 1
			end
		end

		for i = 0, 255 do
			if charmap[i] == 0xff then
				charmap[i] = k
			end
		end
		k = k + 1
	end

	local transitions = ffi.new('uint16_t[?]', id * k)
	for _, node in pairs(nodes) do
		for i = 1, k do
			local index = node.id * k + i - 1
			transitions[index] = start.id
		end

		for c, child in pairs(node) do
			if type(child) == 'table' then
				local index = node.id * k + charmap[string.byte(c)]
				transitions[index] = child.id
			end
		end
	end

	local o = {
		transitions = transitions,
		states = id,
		alphabet = k,
		charmap = charmap,
		accepts = accepts,
		start = start.id,
	}
	setmetatable(o, self)
	return o
end

function M:feed(state, input)
	state = state or self.start
	for i = 1, #input do
		local c = self.charmap[(string.byte(input, i))]
		state = self.transitions[state * self.alphabet + c]
		state = bit.band(state, 0x7fff)
	end
	return state
end

return M
