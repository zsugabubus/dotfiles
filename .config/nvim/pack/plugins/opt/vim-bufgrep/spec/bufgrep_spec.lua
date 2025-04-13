local vim = create_vim({ isolate = false })

local function test_command(Command, add)
	local function make_item(bufname, lnum, col, end_lnum, end_col, text)
		return {
			bufnr = vim.fn.bufnr(bufname),
			col = col,
			end_col = end_col,
			end_lnum = end_lnum,
			lnum = lnum,
			module = '',
			nr = 0,
			pattern = '',
			text = text,
			type = '',
			valid = 1,
			vcol = 0,
		}
	end

	local function assert_quickfix(items)
		return assert.same(items, vim.fn.getqflist())
	end

	it(add and 'appends to quickfix list' or 'truncates quickfix list', function()
		vim.fn.setqflist({ { text = '' } })
		assert.same(1, #vim.fn.getqflist())

		Command('.')

		assert.same(add and 1 or 0, #vim.fn.getqflist())
	end)

	it('uses global regex', function()
		vim.cmd.edit('file')
		vim:set_lines({ 'aa' })

		Command('a')

		assert_quickfix({
			make_item('file', 1, 1, 1, 2, 'aa'),
			make_item('file', 1, 2, 1, 3, 'aa'),
		})
	end)

	it('searches all normal and listed buffers', function()
		vim.cmd.edit('file1')
		vim:set_lines({ 'a' })

		vim.cmd.edit('unlisted')
		vim.bo.buflisted = false
		vim:set_lines({ 'x' })

		vim.cmd.edit('nofile')
		vim.bo.buftype = 'nofile'
		vim:set_lines({ 'x' })

		vim.cmd.edit('file2')
		vim:set_lines({ 'a' })

		Command('.')

		assert_quickfix({
			make_item('file1', 1, 1, 1, 2, 'a'),
			make_item('file2', 1, 1, 1, 2, 'a'),
		})
	end)

	it('swallows "No match:" error', function()
		-- XXX: For some unknown reasons we get "No match" error for the first
		-- buffer only.
		vim.cmd.edit('file1')
		vim.cmd.edit('file2')
		vim:set_lines({ 'a' })

		Command('a')

		assert_quickfix({
			make_item('file2', 1, 1, 1, 2, 'a'),
		})
	end)

	it('swallows "No match" error', function()
		vim.o.wildignore = 'file1'
		vim.cmd.edit('file1')
		vim.cmd.edit('file2')
		vim:set_lines({ 'a' })

		Command('a')

		assert_quickfix({
			make_item('file2', 1, 1, 1, 2, 'a'),
		})
	end)

	it("doesn't swallow regex syntax errors", function()
		vim:set_lines({ '' })

		assert.error_matches(function()
			Command('\\va**')
		end, 'multi follow a multi')
	end)

	describe('allows searching for special character', function()
		local function check(char)
			it(vim.inspect(char), function()
				vim.cmd.edit('file')
				vim:set_lines({ char })

				Command(char)

				assert_quickfix({
					make_item('file', 1, 1, 1, 2, char),
				})
			end)
		end

		check('/')
		check('#')
		check('\\')
		check('%')
	end)

	it('allows backslash escaping in regex', function()
		vim.cmd.edit('file')
		vim:set_lines({ 'a.' })

		Command([[\.]])

		assert_quickfix({
			make_item('file', 1, 2, 1, 3, 'a.'),
		})
	end)

	it('uses last pattern when called without arguments', function()
		vim.fn.setreg('/', 'b')
		vim.cmd.edit('file')
		vim:set_lines({ 'abc' })

		Command()

		assert_quickfix({
			make_item('file', 1, 2, 1, 3, 'abc'),
		})
	end)

	it('keeps last pattern', function()
		vim.fn.setreg('/', 'old')

		Command('new')

		assert.same('old', vim.fn.getreg('/'))
	end)
end

describe(':BufGrep', function()
	test_command(vim.cmd.BufGrep, false)
end)

describe(':BufGrepAdd', function()
	test_command(vim.cmd.BufGrepAdd, true)
end)
