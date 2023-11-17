local function assert_lines(expected)
	local got = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	assert.are.same(expected, got)
end

local function feed(keys)
	return vim.api.nvim_feedkeys(keys, 'xtim', true)
end

local function set_lines(lines)
	return vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

before_each(function()
	vim.go.wrapscan = false
end)

describe('*', function()
	test('sets register /', function()
		set_lines({ 'abc' })
		feed('*rX')
		assert.are.same(vim.fn.getreg('/'), [[\V\<abc\>]])
	end)

	test('handles special characters', function()
		set_lines({ '\\', '*' })
		feed('vj*')
		assert.are.same(vim.fn.getreg('/'), [[\V\<\\\n*\>]])
	end)

	test('works in terminal normal mode', function()
		vim.cmd.terminal('echo abc')
		vim.wait(50)
		feed('*')
		assert.are.same(vim.fn.getreg('/'), [[\V\<abc\>]])
	end)

	test('can find current word', function()
		set_lines({ '   abc abc' })
		feed('*r*')
		assert_lines({ '   *bc abc' })
	end)

	test('displays error when cannot find current word', function()
		local nvim_echo = spy.on(vim.api, 'nvim_echo')
		set_lines({ '', 'abc' })
		feed('*r*')
		assert_lines({ '', 'abc' })
		assert.spy(nvim_echo).was_called()
	end)

	test('keeps options', function()
		local function f()
			vim.bo.modified = false
			return vim.api.nvim_exec('browse set', {})
		end
		local original = f()
		set_lines({ 'abc' })
		feed('*')
		assert.are.same(original, f())
	end)

	describe('on first letter', function()
		before_each(function()
			set_lines({ 'abc', 'abc', 'abc' })
			feed('*')
		end)

		test('*', function()
			feed('r*')
			assert_lines({ 'abc', '*bc', 'abc' })
		end)

		test('**', function()
			feed('*r*')
			assert_lines({ 'abc', 'abc', '*bc' })
		end)

		test('***', function()
			feed('**r*')
			assert_lines({ 'abc', 'abc', '*bc' })
		end)

		test('*n', function()
			feed('nrn')
			assert_lines({ 'abc', 'abc', 'nbc' })
		end)

		test('*N', function()
			feed('NrN')
			assert_lines({ 'Nbc', 'abc', 'abc' })
		end)
	end)

	describe('on second letter', function()
		before_each(function()
			set_lines({ 'abc', 'abc', 'abc' })
			feed('l*')
		end)

		test('*', function()
			feed('r*')
			assert_lines({ 'abc', 'a*c', 'abc' })
		end)

		test('**', function()
			feed('*r*')
			assert_lines({ 'abc', 'abc', 'a*c' })
		end)

		test('***', function()
			feed('**r*')
			assert_lines({ 'abc', 'abc', 'a*c' })
		end)

		test('*n', function()
			feed('nrn')
			assert_lines({ 'abc', 'abc', 'anc' })
		end)

		test('*N', function()
			feed('NrN')
			assert_lines({ 'aNc', 'abc', 'abc' })
		end)
	end)
end)

describe('#', function()
	test('sets register /', function()
		set_lines({ 'abc' })
		feed('*rX')
		assert.are.same(vim.fn.getreg('/'), [[\V\<abc\>]])
	end)

	describe('on last letter', function()
		before_each(function()
			set_lines({ 'abc', 'abc', 'abc' })
			feed('G$#')
		end)

		test('#', function()
			feed('r#')
			assert_lines({ 'abc', 'ab#', 'abc' })
		end)

		test('##', function()
			feed('#r#')
			assert_lines({ 'ab#', 'abc', 'abc' })
		end)

		test('###', function()
			feed('##r#')
			assert_lines({ 'ab#', 'abc', 'abc' })
		end)

		test('#n', function()
			feed('nrn')
			assert_lines({ 'abc', 'abc', 'abn' })
		end)

		test('#N', function()
			feed('NrN')
			assert_lines({ 'abN', 'abc', 'abc' })
		end)
	end)
end)

describe('g*', function()
	test('sets register /', function()
		set_lines({ 'abc' })
		feed('g*')
		assert.are.same(vim.fn.getreg('/'), [[\Vabc]])
	end)
end)

describe('g#', function()
	test('sets register /', function()
		set_lines({ 'abc' })
		feed('g#')
		assert.are.same(vim.fn.getreg('/'), [[\Vabc]])
	end)
end)
