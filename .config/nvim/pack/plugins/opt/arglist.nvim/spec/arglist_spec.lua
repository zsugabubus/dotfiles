local vim = create_vim()

test('Args', function()
	vim.cmd.Args()
	assert.same('args://', vim.fn.expand('%'))
	vim:assert_lines({ '' })

	vim.cmd.enew()

	vim.cmd.args({ 'foo', 'bar', 'baz' })
	vim.cmd.argument(2)
	vim.cmd.edit('args://')
	vim:assert_lines({ 'foo', 'bar', 'baz' })
	vim:assert_cursor('args://', 2, 1)
end)

test('args://', function()
	vim.cmd.args('foo bar baz')
	vim.cmd.argument(3)
	vim.cmd.edit('args://')
	vim:assert_lines({ 'foo', 'bar', 'baz' })
	vim:assert_cursor('args://', 3, 1)

	vim.cmd.argdelete('*')
	vim.cmd.argadd([[\ vim:\ a]])
	vim.cmd.edit()
	vim:assert_lines({ ' vim: a' })

	local arglist = { 'path/to/a.lua', '%', '#', '*' }
	for i = 1, 100 do
		table.insert(arglist, 'x' .. i)
	end
	vim:set_lines(arglist)
	vim.cmd.update()
	assert.same(arglist, vim.fn.argv())

	vim.cmd.argdelete('*')
	assert.same({}, vim.fn.argv())
	vim.cmd.write()
	assert.same(arglist, vim.fn.argv())

	assert.same(0, vim.fn.argidx())
	vim:feed('2Ggf')
	assert.same(arglist[2], vim.fn.expand('%'))
	assert.same(1, vim.fn.argidx())

	vim:assert_messages('')
end)
