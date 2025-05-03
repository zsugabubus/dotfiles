local vim = create_vim({
	width = 100,
	height = 20,
	on_setup = function(vim)
		vim.cmd.runtime('plugin/gzip.vim')
		vim.o.cmdheight = 10
		vim.keymap.set('', 'ga', '<Plug>(vnicode-inspect)')
	end,
})

local function assert_statusline(expected)
	local actual = vim:get_screen()
	for _ = 1, 10 do
		table.remove(actual, 1)
	end
	while actual[#actual] == '' do
		table.remove(actual)
	end
	assert.same(expected, actual)
end

local function assert_vnicode_buffer(lines)
	assert.True(vim.bo.readonly)
	vim:assert_lines(lines)
	vim.cmd.edit()
	vim:assert_lines(lines)
end

describe('ga', function()
	test('ASCII character, normal mode', function()
		vim:set_lines({ 'abc' })
		vim:feed('ga')
		assert_statusline({
			'< a >97, U+0061, Ll/LATIN SMALL LETTER A',
		})
	end)

	test('Unicode character, normal mode', function()
		vim:set_lines({ '🌍x' })
		vim:feed('ga')
		assert_statusline({
			'< 🌍 >127757, U+1F30D, So/EARTH GLOBE EUROPE-AFRICA',
		})
	end)

	test('single ASCII character, visual mode', function()
		vim:set_lines({ 'ax' })
		vim:feed('vga')
		assert_statusline({
			'< a >97, U+0061, Ll/LATIN SMALL LETTER A',
		})
	end)

	test('single Unicode character, visual mode', function()
		vim:set_lines({ '🌍x' })
		vim:feed('vga')
		assert_statusline({
			'< 🌍 >127757, U+1F30D, So/EARTH GLOBE EUROPE-AFRICA',
		})
	end)

	test('multiple lines, charwise visual mode', function()
		vim:set_lines({ 'x2', '34x' })
		vim:feed('lvjga')
		assert_statusline({
			'< 2 >50, U+0032, Nd/DIGIT TWO',
			'< ^J >10, U+000A, Cc/EOL (<control>)',
			'< 3 >51, U+0033, Nd/DIGIT THREE',
			'< 4 >52, U+0034, Nd/DIGIT FOUR',
		})
	end)

	test('multiple lines, linewise visual mode', function()
		vim:set_lines({ '1', '23', 'x' })
		vim:feed('Vjga')
		assert_statusline({
			'< 1 >49, U+0031, Nd/DIGIT ONE',
			'< ^J >10, U+000A, Cc/EOL (<control>)',
			'< 2 >50, U+0032, Nd/DIGIT TWO',
			'< 3 >51, U+0033, Nd/DIGIT THREE',
			'< ^J >10, U+000A, Cc/EOL (<control>)',
		})
	end)
end)

test(':VnicodeInspect', function()
	vim.cmd.VnicodeInspect()
	assert_vnicode_buffer({
		'(nothing to show)',
	})

	vim.cmd.VnicodeInspect('abc')
	assert_vnicode_buffer({
		'< a >97, U+0061, Ll/LATIN SMALL LETTER A',
		'< b >98, U+0062, Ll/LATIN SMALL LETTER B',
		'< c >99, U+0063, Ll/LATIN SMALL LETTER C',
	})

	vim.cmd.VnicodeInspect('a b c')
	assert_vnicode_buffer({
		'< a >97, U+0061, Ll/LATIN SMALL LETTER A',
		'<   >32, U+0020, Zs/SP (SPACE)',
		'< b >98, U+0062, Ll/LATIN SMALL LETTER B',
		'<   >32, U+0020, Zs/SP (SPACE)',
		'< c >99, U+0063, Ll/LATIN SMALL LETTER C',
	})

	vim.cmd.VnicodeInspect('\raőﬁ🌍\u{10ffff}')
	assert_vnicode_buffer({
		'< ^M >13, U+000D, Cc/CR (<control>)',
		'< a >97, U+0061, Ll/LATIN SMALL LETTER A',
		'< ő >337, U+0151, Ll/LATIN SMALL LETTER O WITH DOUBLE ACUTE = < o >+< ◌̋ >',
		'< ﬁ >64257, U+FB01, Ll/LATIN SMALL LIGATURE FI = < f >+< i >',
		'< 🌍 >127757, U+1F30D, So/EARTH GLOBE EUROPE-AFRICA',
		'< <10ffff> >1114111, U+10FFFF, Cn/NO NAME',
	})
end)
