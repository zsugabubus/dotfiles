local hrtime = vim.loop.hrtime
local table_insert = table.insert
local type = type

local stack = { {} }

-- Example:
-- ```
-- a = trace("a")
--   b = trace("a / b")
--   c = trace(b, "a / c") -- Stop "b", start "c".
--     trace("a / c / d")
--   trace(c) -- Stop "c" (auto-closes all children).
-- trace(a)
-- ```
local function trace(node, name)
	local now = hrtime()

	if type(node) == 'table' then
		repeat
			local pop = stack[#stack]
			stack[#stack] = nil
			table_insert(stack[#stack], pop)

			pop.stop = now
		until pop == node
	else
		name = node
	end

	if type(name) == 'string' then
		local node = {
			start = now,
			stop = 0,
			name = name,
		}
		table_insert(stack, node)
		return node
	end
end

local function trace_disabled()
	-- Do nothing.
end

local M = setmetatable({
	trace = trace_disabled,
	verbose = 0,
}, {
	__index = function(M, k)
		getmetatable(M).__index = require('trace-more')
		return M[k]
	end,
})

function M.setup(opts)
	if opts.clear then
		stack = { {} }
	end
	M.trace = opts.verbose > 0 and trace or trace_disabled
	M.verbose = opts.verbose
end

return M
