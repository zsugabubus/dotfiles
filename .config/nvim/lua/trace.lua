local hrtime = vim.loop.hrtime
local table_insert = table.insert
local type = type

local stack = { {} }

-- Example:
-- ```
-- a = trace("a")
--   ab1 = trace("a / b1")
--   ab2 = trace(ab1, "a / b2") -- Stop and start new.
--     trace("a / b2 / c")
--   trace(ab2) -- Stop (including child).
-- trace(span)
-- ```
local function trace(node, name)
	local now = hrtime()

	if type(node) == 'table' then
		repeat
			local pop = stack[#stack]
			stack[#stack] = nil
			table_insert(stack[#stack], pop)

			pop.stop = now
			pop.elapsed = now - pop.start
		until pop == node
	else
		name = node
	end

	if type(name) == 'string' then
		local node = {
			start = now,
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
	__index = function(self, k)
		return require('trace-more')[k]
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
