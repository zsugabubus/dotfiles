local function assert_lines(expected)
	local got = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	assert.are.same(expected, got)
end

test(':Capture', function()
	vim.cmd.Capture([[lua print('te' .. 'st')]])
	assert_lines({ 'test' })
end)

test(':edit', function()
	vim.g._ = 'old'
	vim.cmd.Capture([[lua print(vim.g._)]])
	assert_lines({ 'old' })
	vim.g._ = 'new'
	vim.cmd.edit()
	assert_lines({ 'new' })
end)
