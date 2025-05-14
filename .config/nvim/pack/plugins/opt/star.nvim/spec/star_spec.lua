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

	it('finds current word', function()
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

	context('in charwise visual mode', function()
		it('sets register /', function()
			vim:set_lines({ '12', '345' })
			vim:feed('vlj*')
			assert_pattern([[\V\<12\n34\>]])
		end)

		it('finds multiline', function()
			vim:set_lines({ 'a', 'b', 'a', 'b' })
			vim:feed('vj*r*')
			vim:assert_lines({ 'a', 'b', '*', 'b' })
		end)
	end)

	context('in linewise visual mode', function()
		it('sets register /', function()
			vim:set_lines({ '12', '345' })
			vim:feed('Vj*')
			assert_pattern([[\V\<12\n345\n\>]])
		end)
	end)

	context('in terminal normal mode', function()
		it('sets register /', function()
			vim.cmd.terminal('echo abc')
			vim.wait(50)
			vim:feed('*')
			assert_pattern([[\V\<abc\>]])
		end)
	end)

	it('keeps options', function()
		local function stringify_options()
			vim.bo.modified = false
			return vim:vim('set!')
		end
		local original = stringify_options()
		vim:set_lines({ 'abc' })
		vim:feed('*')
		assert.same(original, stringify_options())
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

	context('on second letter', function()
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

	context('on last letter', function()
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

	context('in charwise visual mode', function()
		it('sets register /', function()
			vim:set_lines({ '12', '345' })
			vim:feed('vljg*')
			assert_pattern([[\V12\n34]])
		end)

		it('finds /', function()
			vim:set_lines({ '/', '/' })
			vim:feed('vg*r*')
			vim:assert_lines({ '/', '*' })
		end)

		it('finds \\', function()
			vim:set_lines({ '\\', '\\' })
			vim:feed('vg*r*')
			vim:assert_lines({ '\\', '*' })
		end)
	end)
end)

describe('g#', function()
	it('sets register /', function()
		vim:set_lines({ 'abc' })
		vim:feed('g#')
		assert_pattern([[\Vabc]])
	end)
end)
