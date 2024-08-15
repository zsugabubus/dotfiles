local vim = create_vim({ isolate = false })

local function command_tests(Command, add)
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
		vim.cmd.edit('test')
		vim:set_lines({ 'aa' })

		Command('a')

		assert_quickfix({
			make_item('test', 1, 1, 1, 2, 'aa'),
			make_item('test', 1, 2, 1, 3, 'aa'),
		})
	end)

	it('searches all buffers', function()
		vim.cmd.edit('a')
		vim:set_lines({ 'a' })

		vim.cmd.edit('b')
		-- No match.

		vim.cmd.edit('c')
		vim:set_lines({ 'c' })

		vim.cmd.edit('d')
		-- No match.

		vim.cmd.edit('unlisted')
		vim.bo.buflisted = false
		vim:set_lines({ 'x' })

		vim.cmd.edit('nofile')
		vim.bo.buftype = 'nofile'
		vim:set_lines({ 'x' })

		Command('.')

		assert_quickfix({
			make_item('a', 1, 1, 1, 2, 'a'),
			make_item('c', 1, 1, 1, 2, 'c'),
		})
	end)

	local function special_char(char)
		it('allows search for special character; ' .. vim.inspect(char), function()
			vim.cmd.edit('test')
			vim:set_lines({ char })

			Command(char)

			assert_quickfix({
				make_item('test', 1, 1, 1, 2, char),
			})
		end)
	end

	special_char('/')
	special_char('#')
	special_char('\\')
	special_char('%')

	it('allows backslash escaping in regex', function()
		vim.cmd.edit('test')
		vim:set_lines({ 'a.' })

		Command([[\.]])

		assert_quickfix({
			make_item('test', 1, 2, 1, 3, 'a.'),
		})
	end)

	it('uses last pattern when called without arguments', function()
		vim.fn.setreg('/', 'b')
		vim.cmd.edit('test')
		vim:set_lines({ 'abc' })

		Command()

		assert_quickfix({
			make_item('test', 1, 2, 1, 3, 'abc'),
		})
	end)

	it('keeps last pattern', function()
		vim.fn.setreg('/', 'old')

		Command('new')

		assert.same('old', vim.fn.getreg('/'))
	end)
end

describe(':BufGrep', function()
	command_tests(vim.cmd.BufGrep, false)
end)

describe(':BufGrepAdd', function()
	command_tests(vim.cmd.BufGrepAdd, true)
end)
