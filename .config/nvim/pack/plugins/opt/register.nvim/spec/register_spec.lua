local function assert_lines(expected)
	local got = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	assert.are.same(expected, got)
end

local function set_lines(lines)
	return vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

test(':Register', function()
	vim.fn.setreg('x', 'aaa\naaa')
	vim.cmd.Register('x')
	assert_lines({ 'aaa', 'aaa' })
end)

test(':edit', function()
	vim.cmd.Register('x')
	vim.fn.setreg('x', 'bbb\nbbb')
	vim.cmd.edit()
	assert_lines({ 'bbb', 'bbb' })
end)

test(':write', function()
	vim.cmd.Register('x')
	set_lines({ 'ccc', 'ccc' })
	vim.cmd.write()
	assert.are.same(vim.fn.getreg('x'), 'ccc\nccc\n')
end)
