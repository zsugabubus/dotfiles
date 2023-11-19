local M = {}

function M.elapsed_time(node, earlier)
	return node.start - earlier.start
end

function M.total_time(node)
	return node.stop - node.start
end

function M.child_time(node)
	local total = 0
	for _, child in ipairs(node) do
		total = total + M.total_time(child)
	end
	return total
end

function M.self_time(node)
	return M.total_time(node) - M.child_time(node)
end

function M.report(root)
	local buf = require('string.buffer').new()
	buf:putf('%11s %11s %11s %s\n', 'clock', 'total', 'self', 'event')

	local function walk(node, depth)
		buf:putf(
			'%8.3f ms %8.3f ms %8.3f ms %s%s\n',
			M.elapsed_time(node, root) / 1e6,
			M.total_time(node) / 1e6,
			M.self_time(node) / 1e6,
			string.rep(' ', depth * 2),
			node.name
		)

		for _, child in ipairs(node) do
			walk(child, depth + 1)
		end
	end

	walk(root, 0)

	return buf:tostring()
end

function M.startuptime(verbose)
	local Trace = require('trace')

	Trace.setup({ verbose = verbose })
	local root = Trace.trace('startup')
	local span

	vim.api.nvim_create_autocmd('VimEnter', {
		once = true,
		callback = function()
			span = Trace.trace('VimEnter')
		end,
	})

	vim.api.nvim_create_autocmd('UIEnter', {
		once = true,
		callback = function()
			Trace.trace(span, 'UIEnter')
			Trace.trace(root)
			vim.api.nvim_echo({ { M.report(root), 'Normal' } }, true, {})
		end,
	})
end

return M
