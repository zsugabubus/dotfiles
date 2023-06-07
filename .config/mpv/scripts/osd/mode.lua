local M = {}
M.__index = M

local serial = 2

local REPEATABLE = { repeatable = true }

function M.new()
	serial = serial + 1

	local default_key_bindings = {
		j = 'DOWN',
		k = 'UP',
		h = 'LEFT',
		l = 'RIGHT',
		J = 'Shift+DOWN',
		K = 'Shift+UP',
		H = 'Shift+LEFT',
		L = 'Shift+RIGHT',
		g = 'HOME',
		G = 'END',
		q = 'ESC',
		d = 'DEL',
		['Ctrl+l'] = 'F5',
	}

	local o = {
		key_bindings = default_key_bindings,
		binding_prefix = string.format('mode-%d-', serial),
		added = false,
	}
	setmetatable(o, M)
	return o
end

function M:map(lhs, rhs)
	-- { A = f, B = g }
	if type(lhs) == 'table' then
		for lhs, rhs in pairs(lhs) do
			self:map(lhs, rhs)
		end
		return
	end

	-- A..B = f
	local low, high = string.match(lhs, '(.+)%.%.(.+)')
	if low then
		assert(type(rhs) == 'function', type(rhs))
		for c = string.byte(low), string.byte(high) do
			local i = c - string.byte(low)
			self:map(string.char(c), function(...)
				return rhs(i, ...)
			end)
		end
		return
	end

	-- A = f
	self.key_bindings[lhs] = rhs
end

local function add_key_binding(self, lhs, rhs)
	while type(rhs) ~= 'function' do
		if not rhs then
			return
		end
		rhs = self.key_bindings[rhs]
	end

	mp.add_forced_key_binding(lhs, self.binding_prefix .. lhs, rhs, REPEATABLE)
end

local function remove_key_binding(self, lhs)
	mp.remove_key_binding(self.binding_prefix .. lhs)
end

function M:add_key_bindings()
	if not self.added then
		self.added = true
		for lhs, rhs in pairs(self.key_bindings) do
			add_key_binding(self, lhs, rhs)
		end
	end
end

function M:remove_key_bindings()
	if self.added then
		self.added = false
		for lhs in pairs(self.key_bindings) do
			remove_key_binding(self, lhs)
		end
	end
end

return M
