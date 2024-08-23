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
	it('sets register /', function()
		vim:set_lines({ 'abc' })
		vim:feed('*rX')
		assert_pattern([[\V\<abc\>]])
	end)

	it('handles special characters', function()
		vim:set_lines({ '\\', '*' })
		vim:feed('vj*')
		assert_pattern([[\V\<\\\n*\>]])
	end)

	it('works in terminal normal mode', function()
		vim.cmd.terminal('echo abc')
		vim.wait(50)
		vim:feed('*')
		assert_pattern([[\V\<abc\>]])
	end)

	it('can find current word', function()
		vim:set_lines({ '   abc abc' })
		vim:feed('*r*')
		vim:assert_lines({ '   *bc abc' })
	end)

	it('displays error when cannot find current word', function()
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

	it('keeps options', function()
		local function f()
			vim.bo.modified = false
			return vim:vim('set!')
		end
		local original = f()
		vim:set_lines({ 'abc' })
		vim:feed('*')
		assert.same(original, f())
	end)

	context('on first letter', function()
		before_each(function()
			vim:set_lines({ 'abc', 'abc', 'abc' })
			vim:feed('*')
		end)

		it('*', function()
			vim:feed('r*')
			vim:assert_lines({ 'abc', '*bc', 'abc' })
		end)

		it('**', function()
			vim:feed('*r*')
			vim:assert_lines({ 'abc', 'abc', '*bc' })
		end)

		it('***', function()
			vim:feed('**r*')
			vim:assert_lines({ 'abc', 'abc', '*bc' })
		end)

		it('*n', function()
			vim:feed('nrn')
			vim:assert_lines({ 'abc', 'abc', 'nbc' })
		end)

		it('*N', function()
			vim:feed('NrN')
			vim:assert_lines({ 'Nbc', 'abc', 'abc' })
		end)
	end)

	describe('on second letter', function()
		before_each(function()
			vim:set_lines({ 'abc', 'abc', 'abc' })
			vim:feed('l*')
		end)

		it('*', function()
			vim:feed('r*')
			vim:assert_lines({ 'abc', 'a*c', 'abc' })
		end)

		it('**', function()
			vim:feed('*r*')
			vim:assert_lines({ 'abc', 'abc', 'a*c' })
		end)

		it('***', function()
			vim:feed('**r*')
			vim:assert_lines({ 'abc', 'abc', 'a*c' })
		end)

		it('*n', function()
			vim:feed('nrn')
			vim:assert_lines({ 'abc', 'abc', 'anc' })
		end)

		it('*N', function()
			vim:feed('NrN')
			vim:assert_lines({ 'aNc', 'abc', 'abc' })
		end)
	end)
end)

describe('#', function()
	it('sets register /', function()
		vim:set_lines({ 'abc' })
		vim:feed('*rX')
		assert_pattern([[\V\<abc\>]])
	end)

	describe('on last letter', function()
		before_each(function()
			vim:set_lines({ 'abc', 'abc', 'abc' })
			vim:feed('G$#')
		end)

		it('#', function()
			vim:feed('r#')
			vim:assert_lines({ 'abc', 'ab#', 'abc' })
		end)

		it('##', function()
			vim:feed('#r#')
			vim:assert_lines({ 'ab#', 'abc', 'abc' })
		end)

		it('###', function()
			vim:feed('##r#')
			vim:assert_lines({ 'ab#', 'abc', 'abc' })
		end)

		it('#n', function()
			vim:feed('nrn')
			vim:assert_lines({ 'abc', 'abc', 'abn' })
		end)

		it('#N', function()
			vim:feed('NrN')
			vim:assert_lines({ 'abN', 'abc', 'abc' })
		end)
	end)
end)

describe('g*', function()
	it('sets register /', function()
		vim:set_lines({ 'abc' })
		vim:feed('g*')
		assert_pattern([[\Vabc]])
	end)
end)

describe('g#', function()
	it('sets register /', function()
		vim:set_lines({ 'abc' })
		vim:feed('g#')
		assert_pattern([[\Vabc]])
	end)
end)
