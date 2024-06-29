local vim = create_vim({
	isolate = false,
	on_setup = function(vim)
		vim.go.wrapscan = false
	end,
})

local function assert_pattern(expected)
	return assert.same(expected, vim.fn.getreg('/'))
end

describe('*', function()
	test('sets register /', function()
		vim:set_lines({ 'abc' })
		vim:feed('*rX')
		assert_pattern([[\V\<abc\>]])
	end)

	test('handles special characters', function()
		vim:set_lines({ '\\', '*' })
		vim:feed('vj*')
		assert_pattern([[\V\<\\\n*\>]])
	end)

	test('works in terminal normal mode', function()
		vim.cmd.terminal('echo abc')
		vim.wait(50)
		vim:feed('*')
		assert_pattern([[\V\<abc\>]])
	end)

	test('can find current word', function()
		vim:set_lines({ '   abc abc' })
		vim:feed('*r*')
		vim:assert_lines({ '   *bc abc' })
	end)

	test('displays error when cannot find current word', function()
		vim:set_lines({ '', 'abc' })
		vim:feed('*r*')
		vim:assert_lines({ '', 'abc' })
		assert.same({
			'',
			'abc',
			'~',
			'~',
			'~',
			'1,0',
			'E348: No string under cursor',
		}, vim:get_screen())
	end)

	test('keeps options', function()
		local function f()
			vim.bo.modified = false
			return vim:vim('set!')
		end
		local original = f()
		vim:set_lines({ 'abc' })
		vim:feed('*')
		assert.same(original, f())
	end)

	describe('on first letter', function()
		before_each(function()
			vim:set_lines({ 'abc', 'abc', 'abc' })
			vim:feed('*')
		end)

		test('*', function()
			vim:feed('r*')
			vim:assert_lines({ 'abc', '*bc', 'abc' })
		end)

		test('**', function()
			vim:feed('*r*')
			vim:assert_lines({ 'abc', 'abc', '*bc' })
		end)

		test('***', function()
			vim:feed('**r*')
			vim:assert_lines({ 'abc', 'abc', '*bc' })
		end)

		test('*n', function()
			vim:feed('nrn')
			vim:assert_lines({ 'abc', 'abc', 'nbc' })
		end)

		test('*N', function()
			vim:feed('NrN')
			vim:assert_lines({ 'Nbc', 'abc', 'abc' })
		end)
	end)

	describe('on second letter', function()
		before_each(function()
			vim:set_lines({ 'abc', 'abc', 'abc' })
			vim:feed('l*')
		end)

		test('*', function()
			vim:feed('r*')
			vim:assert_lines({ 'abc', 'a*c', 'abc' })
		end)

		test('**', function()
			vim:feed('*r*')
			vim:assert_lines({ 'abc', 'abc', 'a*c' })
		end)

		test('***', function()
			vim:feed('**r*')
			vim:assert_lines({ 'abc', 'abc', 'a*c' })
		end)

		test('*n', function()
			vim:feed('nrn')
			vim:assert_lines({ 'abc', 'abc', 'anc' })
		end)

		test('*N', function()
			vim:feed('NrN')
			vim:assert_lines({ 'aNc', 'abc', 'abc' })
		end)
	end)
end)

describe('#', function()
	test('sets register /', function()
		vim:set_lines({ 'abc' })
		vim:feed('*rX')
		assert_pattern([[\V\<abc\>]])
	end)

	describe('on last letter', function()
		before_each(function()
			vim:set_lines({ 'abc', 'abc', 'abc' })
			vim:feed('G$#')
		end)

		test('#', function()
			vim:feed('r#')
			vim:assert_lines({ 'abc', 'ab#', 'abc' })
		end)

		test('##', function()
			vim:feed('#r#')
			vim:assert_lines({ 'ab#', 'abc', 'abc' })
		end)

		test('###', function()
			vim:feed('##r#')
			vim:assert_lines({ 'ab#', 'abc', 'abc' })
		end)

		test('#n', function()
			vim:feed('nrn')
			vim:assert_lines({ 'abc', 'abc', 'abn' })
		end)

		test('#N', function()
			vim:feed('NrN')
			vim:assert_lines({ 'abN', 'abc', 'abc' })
		end)
	end)
end)

describe('g*', function()
	test('sets register /', function()
		vim:set_lines({ 'abc' })
		vim:feed('g*')
		assert_pattern([[\Vabc]])
	end)
end)

describe('g#', function()
	test('sets register /', function()
		vim:set_lines({ 'abc' })
		vim:feed('g#')
		assert_pattern([[\Vabc]])
	end)
end)
