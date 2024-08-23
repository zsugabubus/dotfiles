local vim = create_vim({
	isolate = false,
	on_setup = function(vim)
		vim.keymap.set('', 'gc', '<Plug>(commenter)')
		vim.keymap.set('', 'gcc', '<Plug>(commenter-current-line)')
	end,
})

it('toggles single line', function()
	local function test_case(cms, input, output)
		vim.o.cms = cms
		vim:set_lines({ input })
		vim:feed('gcc')
		return vim:assert_lines({ output })
	end

	test_case('', 'a', '# a')
	test_case('/*%s*/', 'a', '/* a */')
	test_case('/*%s*/', '/* a */', 'a')
	test_case('/*%s*/', '/*a*/', 'a')
	test_case('/*%s*/', '/*  a  */', ' a ')
	test_case('/*%s*/', '/**//*a*/', '//*a') -- BAD
	test_case('/*%s*/', '/* *//*a*/', '/*a*/')
	test_case('/*%s*/', '/*** a ***/', 'a')
	test_case('//%s', '//// a', 'a')
	test_case('#%s', '#  a ', ' a ')
	test_case('--%s', 'a--b', '-- a--b')
	test_case('--%s', '----', '')
	test_case('//%s', '', '')
	test_case('//%s', ' ', ' ')
	test_case('/*  %s  */', 'a', '/* a */')
	test_case('/*  %s  */', '/*a*/', 'a')
	test_case('//  %s', 'a', '// a')
	test_case('//  %s', '//a', 'a')
end)

it('toggles multiple lines', function()
	local ORIGINAL = {
		'    a',
		'',
		'     ',
		'  b',
		'\t   c',
		'x',
	}

	local COMMENTED = {
		'  |   a',
		'',
		'     ',
		'  | b',
		'\t |   c',
		'x',
	}

	local function test_case(keys)
		vim.o.cms = '|%s'
		vim:set_lines(ORIGINAL)
		vim:feed(keys)
		vim:assert_lines(COMMENTED)
		vim:feed(keys)
		vim:assert_lines(ORIGINAL)
	end

	test_case('5gcc')
	test_case('gc4j')
	test_case('4gcj')
end)

describe('toggle mixed lines', function()
	it('comments', function()
		vim.o.cms = '*%s'
		vim:set_lines({
			'',
			'a*',
			'*b',
			'x',
		})
		vim:feed('3gcc')
		vim:assert_lines({
			'',
			'* a*',
			'* *b',
			'x',
		})
	end)

	it('uncomments', function()
		vim.o.cms = '*%s'
		vim:set_lines({
			'',
			'* a',
			'c*',
			'x',
		})
		vim:feed('3gcc')
		vim:assert_lines({
			'',
			'a',
			'c*',
			'x',
		})
	end)
end)

it('dot repeat', function()
	local function test_case(keys)
		vim.o.cms = '*%s'
		vim:set_lines({
			'a',
			'b',
			'* c',
			'x',
		})
		vim:feed('gg' .. keys)
		vim:assert_lines({
			'* a',
			'* b',
			'* c',
			'x',
		})
		vim:feed('j.')
		vim:assert_lines({
			'* a',
			'b',
			'c',
			'x',
		})
	end

	test_case('gcj')
	test_case('2gcc')
	test_case('Vjgc')
end)

describe(':Comment', function()
	it('comments current line without range', function()
		vim:set_lines({
			'a',
			'b',
		})
		vim.cmd('Comment')
		vim:assert_lines({
			'# a',
			'b',
		})
	end)

	it('comments range', function()
		vim:set_lines({
			'a',
			'b',
			'c',
			'd',
		})
		vim.cmd('2,3Comment')
		vim:assert_lines({
			'a',
			'# b',
			'# c',
			'd',
		})
	end)

	it('does not uncomment lines', function()
		vim:set_lines({
			'# a',
		})
		vim.cmd('Comment')
		vim:assert_lines({
			'# # a',
		})
	end)
end)

describe(':Uncomment', function()
	it('uncomments current line without range', function()
		vim:set_lines({
			'# a',
			'# b',
		})
		vim.cmd('Uncomment')
		vim:assert_lines({
			'a',
			'# b',
		})
	end)

	it('uncomments range', function()
		vim:set_lines({
			'# a',
			'# b',
			'# c',
			'# d',
		})
		vim.cmd('2,3Uncomment')
		vim:assert_lines({
			'# a',
			'b',
			'c',
			'# d',
		})
	end)

	it('does not comment lines', function()
		vim:set_lines({
			'a',
		})
		vim.cmd('Uncomment')
		vim:assert_lines({
			'a',
		})
	end)
end)

it('reports changed lines', function()
	local function test_case(report, keys, message)
		vim.cmd.echo()
		vim:set_lines({
			'1',
			'2',
			'',
		})
		vim.o.report = report
		vim:feed('gg' .. keys)
		local screen = vim:get_screen()
		local cmdline = screen[#screen]
		return assert.same(message, cmdline)
	end

	test_case(0, '3Ggcc', '--No lines to comment--')
	test_case(0, 'gcc', '1 line commented')
	test_case(0, '1gcc', '1 line commented')
	test_case(0, 'gccgcc', '1 line uncommented')
	test_case(0, 'gcj', '2 lines commented')
	test_case(0, 'gcjgcj', '2 lines uncommented')
	test_case(1, 'gcc', '')
	test_case(1, 'gcj', '2 lines commented')
	test_case(1, '2gcc', '2 lines commented')
	test_case(1, 'gcjgcj', '2 lines uncommented')
	test_case(2, 'gcj', '')
	test_case(2, '3gcc', '3 lines commented')
	test_case(9, '3Ggcc', '--No lines to comment--')
end)
