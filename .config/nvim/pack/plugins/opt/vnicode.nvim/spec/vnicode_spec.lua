local vim = create_vim({
	width = 100,
	height = 5,
	on_setup = function(vim)
		vim.cmd.runtime('plugin/gzip.vim')
		vim.o.cmdheight = 3
		vim:lua(function()
			require('vnicode').setup()
		end)
		vim.keymap.set('', 'ga', '<Plug>(vnicode-inspect)')
	end,
})

test('ga; normal mode', function()
	vim:set_lines({ 'abc' })
	vim:feed('ga')
	assert.same({
		'abc',
		'1,1',
		'< a >97, U+0061, Ll/LATIN SMALL LETTER A',
		'',
		'',
	}, vim:screen())
end)

test('ga; visual mode', function()
	vim:set_lines({ 'a', 'b' })
	vim:feed('vjga')
	assert.same({
		'a',
		'1,1',
		'< a >97, U+0061, Ll/LATIN SMALL LETTER A',
		'< ^J >10, U+000A, Cc/EOL (<control>)',
		'< b >98, U+0062, Ll/LATIN SMALL LETTER B',
	}, vim:screen())
end)

test(':VnicodeInspect', function()
	vim.cmd.VnicodeInspect()
	assert.same('vnicode://', vim.fn.bufname())

	vim.cmd.VnicodeInspect('abc')
	assert.same('vnicode://abc', vim.fn.bufname())

	vim.cmd.VnicodeInspect('a b c')
	assert.same('vnicode://a b c', vim.fn.bufname())
end)

test('vnicode://', function()
	vim.cmd.edit(vim.fn.fnameescape('vnicode://\raőﬁ🌍\u{10ffff}'))
	vim:assert_lines({
		'< ^M >13, U+000D, Cc/CR (<control>)',
		'< a >97, U+0061, Ll/LATIN SMALL LETTER A',
		'< ő >337, U+0151, Ll/LATIN SMALL LETTER O WITH DOUBLE ACUTE = < o >+< ◌̋ >',
		'< ﬁ >64257, U+FB01, Ll/LATIN SMALL LIGATURE FI = < f >+< i >',
		'< 🌍 >127757, U+1F30D, So/EARTH GLOBE EUROPE-AFRICA',
		'< <10ffff> >1114111, U+10FFFF, Cn/NO NAME',
	})
	vim.cmd.edit()
end)
