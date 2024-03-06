local function assert_lines(expected)
	local got = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	assert.are.same(expected, got)
end

local function set_lines(lines)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function feed(keys)
	vim.api.nvim_feedkeys(keys, 'xtim', true)
end

before_each(function()
	vim.keymap.set('', 's', '<Plug>(align)', {})
end)

local function test_margin(input, expected)
	local name =
		string.format('margin; %s -> %s', vim.inspect(input), vim.inspect(expected))
	test(name, function()
		set_lines({ input })
		feed('Vs|')
		assert_lines({ expected })
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
	set_lines({
		'a|b',
		'aaa|b',
	})
	feed('VGs|')
	assert_lines({
		'a   | b',
		'aaa | b',
	})
end)

test('char; ","', function()
	set_lines({
		'a,b',
		'aaa,b',
	})
	feed('VGs,')
	assert_lines({
		'a,   b',
		'aaa, b',
	})
end)

test('char; "="', function()
	set_lines({
		'a=b',
		'aaa=b',
		'a==b',
		'a+=b',
		'a&&=b',
	})
	feed('VGs=')
	assert_lines({
		'a   = b',
		'aaa = b',
		'a   == b',
		'a   += b',
		'a   &&= b',
	})
end)

test('char; ":"', function()
	set_lines({
		'a:bbbbb:c',
		'aaa:b:c',
	})
	feed('VGs:')
	assert_lines({
		'a  : bbbbb:c',
		'aaa: b:c',
	})
end)

test('left align; trailing space', function()
	set_lines({
		'aaa',
		'a,',
	})
	feed('VGs,')
	assert_lines({
		'aaa',
		'a,',
	})
end)

test('alignment; left', function()
	set_lines({
		'  |aaaaaa||b|',
		'  |   aaa   ||b\t   |',
		'  ||',
	})
	feed('VGs|')
	assert_lines({
		'  | aaaaaa | | b         |',
		'  | aaa    | | b\t |',
		'  |        |',
	})
end)

test('alignment; right', function()
	set_lines({
		'  ,a,,bbb,',
		'  ,aaa,,b,c,d',
		'  ,,',
	})
	feed('VGs,')
	assert_lines({
		'  , a,   , bbb,',
		'  , aaa, , b,   c, d',
		'  , ,',
	})
end)

test('range; single-line', function()
	set_lines({
		'|1|',
		'|2|',
		'|3|',
	})
	feed('2GVs|')
	assert_lines({
		'|1|',
		'| 2 |',
		'|3|',
	})
end)

test('range; multi-line, downwards', function()
	set_lines({
		'|1|',
		'|2|',
		'|3|',
		'|4|',
	})
	feed('2GVjs|')
	assert_lines({
		'|1|',
		'| 2 |',
		'| 3 |',
		'|4|',
	})
end)

test('range; multi-line, upwards', function()
	set_lines({
		'|1|',
		'|2|',
		'|3|',
		'|4|',
	})
	feed('3GVks|')
	assert_lines({
		'|1|',
		'| 2 |',
		'| 3 |',
		'|4|',
	})
end)

test('range; operator-pending', function()
	set_lines({
		'|1|',
		'|2|',
		'|3|',
		'|4|',
	})
	feed('2Gs|j')
	assert_lines({
		'|1|',
		'| 2 |',
		'| 3 |',
		'|4|',
	})
end)
