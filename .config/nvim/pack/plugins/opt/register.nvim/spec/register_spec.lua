local vim = create_vim()

test(':Register', function()
	vim.cmd.Register()
	assert.same('reg://', vim.fn.expand('%'))

	vim.cmd.Register('x')
	assert.same('reg://x', vim.fn.expand('%'))
end)

test('reg://', function()
	vim.fn.setreg('', 'a')
	vim.cmd.edit('reg://')
	vim:assert_lines({ 'a' })

	vim.fn.setreg('x', 'a\n\nb\n')
	vim.cmd.edit('reg://x')
	vim:assert_lines({ 'a', '', 'b', '' })

	vim.cmd.write()
	assert.same('a\n\nb\n', vim.fn.getreg('x'))

	vim.fn.setreg('x', ' vim: a\n')
	vim.cmd.edit()
	vim:assert_lines({ ' vim: a', '' })

	vim:assert_messages('')
end)
