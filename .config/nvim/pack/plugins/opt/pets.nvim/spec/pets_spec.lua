local vim = create_vim({})

local function check_paren(open, close)
	local function replace(s)
		return (s:gsub('.', { ['('] = open, [')'] = close }))
	end

	local function check_multiline(lines, input, expected)
		vim:set_lines(vim.tbl_map(replace, lines))
		vim:feed(_G.vim.keycode(replace(input)))
		return vim:assert_lines(vim.tbl_map(replace, expected))
	end

	local function check(input, expected)
		return check_multiline({}, input, { expected })
	end

	check('i(<Esc>', '()')
	check('i()', '()')
	check('i(<Esc>a)', '()')
	check('i))', '))')
	check('i)<Left>)', ')')
	check('i()<Left>)', '()')
	check('i()<Esc>i)', '()')
	check('i()foo', '()foo')
	check('i())foo', '())foo')
	check('i((foo', '((foo))')
	check('i((foo)(bar', '((foo)(bar))')
	check('i((<Del>)', '(())')
	check('i)(foo', ')(foo)')
	check('i)<Left>(foo', '(foo))')
	check('i((<Left>(foo', '((foo())')
	check('i((<Del><Del><Left>(foo', '((foo(')
	check('i(foo', '(foo)')
	check('i(foo)bar', '(foo)bar')
	check('i(foo<Esc>a)bar', '(foo)bar')
	check('i (<Left>(foo', ' (foo()')
	check('i (<Left><Left>(foo', '(foo ()')
	check('i;<Left>(', '();')
	check('i,<Left>(', '(),')

	check([[i" (]], [[" ("]])
	check([[i' (]], [[' (']])
	check([[i` (]], [[` (`]])

	check('i(<BS>foo', 'foo')
	check('i(<C-H>foo', 'foo')
	check('i(<Esc>a<BS>foo', 'foo')
	check('i(x<BS><BS>foo', 'foo')
	check('ifoo(bar<C-W><C-W>baz', 'foobaz')
	check('i foo(bar<C-U>baz', ' baz')
	check('i()<BS>foo', '(foo')
	check('i()<BS>)foo', '()foo')
	check('i()<BS>))foo', '())foo')
	check('i((<BS>foo', '(foo)')
	check('i((<BS><BS>foo', 'foo')
	check('i(())<BS><BS>foo', '((foo')
	check('i(()<BS><BS>foo', '(foo)')
	check('ia(b(c)<BS><BS><BS>foo', 'a(bfoo)')
	check('ia(b(c))<Left><BS><BS><BS>foo', 'a(bfoo)')
	check('ia(b(c))<Left><Left><BS><BS>foo', 'a(bfoo)')
	check('ia(b(c))<Left><Left><BS><BS><BS><BS>foo', 'afoo')
	check('i)))(<BS>foo', ')))foo')
	check('i()()()<Left><Left><BS><BS>foo', '()foo()')

	check('iorig<Esc>ccfoo(()<BS><BS><BS><Esc>u', 'orig')

	check('Afoo(()bar<Esc>.', ('foo(()bar)'):rep(2))

	check_multiline({ '', ')' }, '1GI)foo', { ')foo', ')' })
	check_multiline({ ' ', ')' }, '1GI)foo', { ' )foo', ')' })
	check_multiline({ ',', ')' }, '1GI)foo', { ')foo,', ')' })
	check_multiline({ ';', ')' }, '1GI)foo', { ')foo;', ')' })
	check_multiline({ 'x', ')' }, '1GI)foo', { ')foox', ')' })
	check_multiline({ '(', ')' }, '1GA)foo', { '()foo', ')' })
	check_multiline({ '()', ' \t )' }, '1GA)foo', { '()', ' \t )foo' })
	check_multiline({ '()', '', ')' }, '1GA)foo', { '())foo', '', ')' })
	check_multiline({ '()', 'x)' }, '1GA)foo', { '())foo', 'x)' })
end

local function check_quote(quote)
	local function replace(s)
		return (s:gsub('"', quote))
	end

	local function check(input, expected)
		vim:set_lines({})
		vim:feed(_G.vim.keycode(replace(input)))
		return vim:assert_lines({ replace(expected) })
	end

	check('i"foo', '"foo"')
	check('i""foo', '""foo')
	check('i"""', '"""')
	check('i"" "', '"" ""')
	check('i"<Del>foo"', '"foo"')
	check('i"foo"bar', '"foo"bar')
	check('i"foo\\"bar', '"foo\\"bar"')
	check('i"foo\\""', '"foo\\""')
	check('i"foo\\"""', '"foo\\"""')

	check('i"<BS>foo', 'foo')
	check('i""<BS>foo', '"foo')
	check('i"\\"<BS>foo', '"\\foo"')
	check('i"\\""<BS>x', '"\\"x')
	check('i"\\""<BS>x"', '"\\"x"')
	check('i"\\""<Left><BS>n', '"\\n"')
	check('i"\\"\\""<Left><BS>n', '"\\"\\n"')

	check('iorig<Esc>cc"foo"<Esc>u', 'orig')
	check('iorig<Esc>cc"foo\\""<Esc>u', 'orig')

	check('Afoo"bar\\""baz<Esc>.', ('foo"bar\\""baz'):rep(2))

	check('i"a","b', '"a","b"')
	check('i"a\\"b","c', '"a\\"b","c"')
	check('ix<Left>"', '"x')
	local punct = ':,; ()[]{}'
	check('i""' .. punct .. '<Esc>I"x', '"x"' .. punct)
	check('i""x<Left>"', '"""x')
	check('i"x"<Left>"', '"x"')
	check('i""<Left><Left>""', '""')
	check('i"a"<Esc>I"b",', '"b","a"')
end

test('parens', function()
	check_paren('(', ')')
	check_paren('[', ']')
	check_paren('{', '}')
end)

test('parens in lua', function()
	local function check(input, expected)
		vim:set_lines({})
		vim:feed(_G.vim.keycode(input))
		return vim:assert_lines({ expected })
	end

	vim.bo.filetype = 'lua'
	check('i[', '[')
	check('i[===[', '[===[')
	check('i]<Left>]', ']]')
end)

test('parens in rust', function()
	vim.bo.filetype = 'rust'
	vim:set_lines({ 'orig' })
	vim:feed(_G.vim.keycode('cc{foo = {bar'))
	vim:assert_lines({
		'{',
		'    foo = {',
		'        bar',
		'    }',
		'}',
	})
	vim.cmd.undo()
	vim:assert_lines({ 'orig' })
end)

test('quotes', function()
	local function check(input, expected)
		vim:set_lines({})
		vim:feed(_G.vim.keycode(input))
		return vim:assert_lines({ expected })
	end

	check_quote('"')
	check_quote("'")
	check_quote('`')

	check('ix"', 'x""')

	check("i 'foo", " 'foo'")
	check("i='foo", "='foo'")
	check("iA's", "A's")
	check("iz's", "z's")

	check('ix`', 'x``')
end)
