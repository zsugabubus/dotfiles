local M = {}

function M.report(node)
	local epoch = node.start

	local buf = require 'string.buffer'.new()
	buf:putf('%11s %11s %11s %s\n', 'clock', 'total', 'self', 'event')

	local function walk(node, depth)
		local children_elapsed = 0
		for _, child in ipairs(node) do
			children_elapsed = children_elapsed + child.elapsed
		end

		buf:putf(
			'%8.3f ms %8.3f ms %8.3f ms %s%s\n',
			(node.start - epoch) / 1e6,
			node.elapsed / 1e6,
			(node.elapsed - children_elapsed) / 1e6,
			string.rep(' ', depth * 2),
			node.name
		)

		for _, child in ipairs(node) do
			walk(child, depth + 1)
		end
	end

	walk(node, 0)

	return buf:tostring()
end

function M.startuptime(verbose)
	local Trace = require 'trace'

	Trace.setup { verbose = verbose }
	local root = Trace.trace('startup')

	vim.api.nvim_create_autocmd('VimEnter', {
		callback = function()
			Trace.trace(root)
			vim.api.nvim_echo({{M.report(root), 'Normal'}}, true, {})
		end,
	})
end

return M
