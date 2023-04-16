local M = {}

function M.report(node)
	local lines = {
		string.format('%11s %11s %11s %s', 'clock', 'total', 'self', 'event'),
	}
	local epoch = node.start

	local function walk(node, depth)
		local children_elapsed = 0
		for _, child in ipairs(node) do
			children_elapsed = children_elapsed + child.elapsed
		end

		table.insert(lines, string.format(
			'%8.3f ms %8.3f ms %8.3f ms %s%s',
			(node.start - epoch) / 1e6,
			node.elapsed / 1e6,
			(node.elapsed - children_elapsed) / 1e6,
			string.rep(' ', depth * 2),
			node.name
		))

		for _, child in ipairs(node) do
			walk(child, depth + 1)
		end
	end

	walk(node, 0)

	return table.concat(lines, '\n')
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
