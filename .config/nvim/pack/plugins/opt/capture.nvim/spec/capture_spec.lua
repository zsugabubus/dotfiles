local vim = create_vim()

test(':Capture', function()
	vim.cmd.Capture([[lua print('te' .. 'st')]])
	vim:assert_lines({ 'test' })
end)

test(':edit', function()
	vim.g._ = 'old'
	vim.cmd.Capture([[lua print(vim.g._)]])
	vim:assert_lines({ 'old' })
	vim.g._ = 'new'
	vim.cmd.edit()
	vim:assert_lines({ 'new' })
end)
