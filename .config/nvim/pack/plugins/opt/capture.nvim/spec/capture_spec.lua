local vim = create_vim()

test(':Capture', function()
	vim.cmd.echom('"a"')
	vim.cmd.echom('"b"')
	vim.cmd.Capture()
	vim:assert_lines({ 'a', 'b' })

	vim.cmd.Capture([[lua print(' vim: a')]])
	vim:assert_lines({ ' vim: a' })
end)

test(':edit', function()
	vim.g._ = 'old'
	vim.cmd.Capture([[lua print(vim.g._)]])
	vim:assert_lines({ 'old' })
	vim.g._ = 'new'
	vim.cmd.edit()
	vim:assert_lines({ 'new' })
end)
