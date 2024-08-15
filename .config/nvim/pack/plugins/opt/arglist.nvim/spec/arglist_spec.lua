local vim = create_vim()

describe(':Args', function()
	it('edits args://', function()
		vim.cmd.Args()
		assert.same('args://', vim.fn.expand('%'))
		vim:assert_lines({ '' })
	end)

	it('unloads hidden args:// and reloads it when entered', function()
		vim.cmd.Args()
		vim.cmd.enew()
		assert.True(vim.fn.bufnr('args://') > 0)
		assert.same(0, vim.fn.bufloaded('args://'))
		vim.cmd.args({ 'foo', 'bar', 'baz' })
		vim.cmd.argument(2)
		vim.cmd.Args()
		vim:assert_lines({ 'foo', 'bar', 'baz' })
		vim:assert_cursor('args://', 2, 1)
	end)
end)

describe('args://', function()
	it(
		'shows correct argument list and sets cursor to the current entry',
		function()
			vim.cmd.args('foo bar \\ vim:\\ a')
			vim.cmd.argument(3)
			vim.cmd.edit('args://')
			vim:assert_lines({ 'foo', 'bar', ' vim: a' })
			vim:assert_cursor('args://', 3, 1)
			assert.False(vim.bo.modeline)
		end
	)

	it(':write sets argument list', function()
		local arglist = { 'path/to/a.lua', '%', '#', '*' }
		for i = 1, 100 do
			table.insert(arglist, 'x' .. i)
		end

		vim.cmd.edit('args://')
		vim:set_lines(arglist)
		vim.cmd.argadd('bla bla bla')
		assert.True(vim.bo.modified)
		vim.cmd.update()
		assert.same('args://', vim.fn.bufname())
		assert.False(vim.bo.modified)
		assert.same(arglist, vim.fn.argv())

		vim.cmd.argdelete('*')
		assert.same({}, vim.fn.argv())

		vim.cmd.write()
		assert.same(arglist, vim.fn.argv())

		vim:assert_messages('')
	end)

	it(
		'gf edits argument under cursor and sets it as the current entry',
		function()
			vim.cmd.args('a b c')
			vim.cmd.edit('args://')
			assert.same(0, vim.fn.argidx())
			vim:feed('2Ggf')
			assert.same('b', vim.fn.bufname())
			assert.same(1, vim.fn.argidx())
		end
	)
end)
