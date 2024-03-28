local vim = create_vim({
	isolate = false,
	on_setup = function(vim)
		vim.keymap.set('', 's', '<Plug>(align)')
	end,
})

local function test_margin(input, expected)
	local name =
		string.format('margin; %s -> %s', vim.inspect(input), vim.inspect(expected))
	test(name, function()
		vim:set_lines({ input })
		vim:feed('Vs|')
		vim:assert_lines({ expected })
	end)
end

test_margin('', '')
test_margin('  ', '  ')
test_margin('||', '| |')
test_margin('|  |', '| |')
test_margin('a', 'a')
test_margin('  a', '  a')
test_margin('a  ', 'a  ')
test_margin('|a|', '| a |')
test_margin('|a', '| a')
test_margin('a|', 'a |')
test_margin('|  a  |', '| a |')
test_margin('|  a  ', '| a  ')
test_margin('  a  |', '  a |')

test('char; "|"', function()
	vim:set_lines({
		'a|b',
		'aaa|b',
	})
	vim:feed('VGs|')
	vim:assert_lines({
		'a   | b',
		'aaa | b',
	})
end)

test('char; ","', function()
	vim:set_lines({
		'a,b',
		'aaa,b',
	})
	vim:feed('VGs,')
	vim:assert_lines({
		'a,   b',
		'aaa, b',
	})
end)

test('char; "="', function()
	vim:set_lines({
		'a=b',
		'aaa=b',
		'a==b',
		'a+=b',
		'a&&=b',
	})
	vim:feed('VGs=')
	vim:assert_lines({
		'a   = b',
		'aaa = b',
		'a   == b',
		'a   += b',
		'a   &&= b',
	})
end)

test('char; ":"', function()
	vim:set_lines({
		'a:bbbbb:c',
		'aaa:b:c',
	})
	vim:feed('VGs:')
	vim:assert_lines({
		'a  : bbbbb:c',
		'aaa: b:c',
	})
end)

test('left align; trailing space', function()
	vim:set_lines({
		'aaa',
		'a,',
	})
	vim:feed('VGs,')
	vim:assert_lines({
		'aaa',
		'a,',
	})
end)

test('alignment; left', function()
	vim:set_lines({
		'  |aaaaaa||b|',
		'  |   aaa   ||b\t   |',
		'  ||',
	})
	vim:feed('VGs|')
	vim:assert_lines({
		'  | aaaaaa | | b         |',
		'  | aaa    | | b\t |',
		'  |        |',
	})
end)

test('alignment; right', function()
	vim:set_lines({
		'  ,a,,bbb,',
		'  ,aaa,,b,c,d',
		'  ,,',
	})
	vim:feed('VGs,')
	vim:assert_lines({
		'  , a,   , bbb,',
		'  , aaa, , b,   c, d',
		'  , ,',
	})
end)

test('range; single-line', function()
	vim:set_lines({
		'|1|',
		'|2|',
		'|3|',
	})
	vim:feed('2GVs|')
	vim:assert_lines({
		'|1|',
		'| 2 |',
		'|3|',
	})
end)

test('range; multi-line, downwards', function()
	vim:set_lines({
		'|1|',
		'|2|',
		'|3|',
		'|4|',
	})
	vim:feed('2GVjs|')
	vim:assert_lines({
		'|1|',
		'| 2 |',
		'| 3 |',
		'|4|',
	})
end)

test('range; multi-line, upwards', function()
	vim:set_lines({
		'|1|',
		'|2|',
		'|3|',
		'|4|',
	})
	vim:feed('3GVks|')
	vim:assert_lines({
		'|1|',
		'| 2 |',
		'| 3 |',
		'|4|',
	})
end)

test('range; operator-pending', function()
	vim:set_lines({
		'|1|',
		'|2|',
		'|3|',
		'|4|',
	})
	vim:feed('2Gs|j')
	vim:assert_lines({
		'|1|',
		'| 2 |',
		'| 3 |',
		'|4|',
	})
end)
