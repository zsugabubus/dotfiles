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
	local UNCOMMENTED = {
		'    a',
		'',
		'     ',
		'  b',
		'\t   c',
	}

	local COMMENTED = {
		'  //   a',
		'',
		'     ',
		'  // b',
		'\t //   c',
	}

	local function test_case(keys)
		vim.o.cms = '//%s'
		vim:set_lines(UNCOMMENTED)
		vim:feed(keys)
		vim:assert_lines(COMMENTED)
		vim:feed(keys)
		vim:assert_lines(UNCOMMENTED)
	end

	test_case('4gcc')
	test_case('gc4j')
	test_case('4gcj')
end)

describe('toggle mixed lines', function()
	before_each(function()
		vim.o.cms = '*%s'
	end)

	it('should do comment', function()
		vim:set_lines({
			'',
			'a*',
			'*b',
		})
		vim:feed('2gcc')
		vim:assert_lines({
			'',
			'* a*',
			'* *b',
		})
	end)

	it('should do uncomment', function()
		vim:set_lines({
			'',
			'* a',
			'c*',
		})
		vim:feed('2gcc')
		vim:assert_lines({
			'',
			'a',
			'c*',
		})
	end)
end)

describe('filetype', function()
	before_each(function()
		vim.cmd.filetype({ args = { 'plugin', 'on' } })
	end)

	describe('unset', function()
		before_each(function()
			vim:set_lines({
				'text',
			})
		end)

		it('uses default commentstring', function()
			vim:feed('gcc')
			vim:assert_lines({
				'# text',
			})
		end)

		it('uses custom commentstring', function()
			vim:feed('gcc')
			vim:feed('gcc')
			vim.o.cms = '//%s'
			vim:feed('gcc')
			vim:assert_lines({
				'// text',
			})
		end)
	end)

	describe('known', function()
		before_each(function()
			assert(vim.o.cms == '')
			vim.o.ft = 'c'
			assert(vim.o.cms ~= '')
			vim:set_lines({
				'code',
			})
		end)

		it('uses custom commentstring', function()
			vim:feed('gcc')
			vim:feed('gcc')
			vim.o.cms = 'BLA %s BLA'
			vim:feed('gcc')
			vim:assert_lines({
				'BLA code BLA',
			})
		end)
	end)

	describe('tsx', function()
		before_each(function()
			vim.o.ft = 'typescriptreact'
			vim:set_lines({
				'(',
				'<html/>',
				')',
			})
		end)

		it('guesses ts correctly', function()
			vim:feed('1Ggcc3Ggcc')
			vim:assert_lines({
				'// (',
				'<html/>',
				'// )',
			})
		end)

		it('guesses html correctly', function()
			pending('How to test treesitter?')
			vim:feed('2Ggcc')
			vim:assert_lines({
				'(',
				'{/* <html/> */}',
				')',
			})
		end)
	end)
end)

describe('dot repeat', function()
	before_each(function()
		vim.o.cms = '*%s'
	end)

	it('works in normal mode', function()
		vim:set_lines({
			'a',
			'b',
			'* c',
		})
		vim:feed('1gcc')
		vim:assert_lines({
			'* a',
			'* b',
			'* c',
		})
		vim:feed('j.')
		vim:assert_lines({
			'* a',
			'b',
			'c',
		})
	end)

	it('works in visual mode', function()
		vim:set_lines({
			'a',
			'b',
			'* c',
		})
		vim:feed('Vjgc')
		vim:assert_lines({
			'* a',
			'* b',
			'* c',
		})
		vim:feed('.')
		vim:assert_lines({
			'a',
			'b',
			'* c',
		})
	end)
end)

describe(':Comment', function()
	it('comments current line without range', function()
		vim:set_lines({
			'a',
			'b',
			'c',
		})
		vim.cmd('Comment')
		vim:assert_lines({
			'# a',
			'b',
			'c',
		})
	end)

	it('comments range', function()
		vim:set_lines({
			'a',
			'b',
			'c',
		})
		vim.cmd('2,3Comment')
		vim:assert_lines({
			'a',
			'# b',
			'# c',
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
			'# c',
		})
		vim.cmd('Uncomment')
		vim:assert_lines({
			'a',
			'# b',
			'# c',
		})
	end)

	it('uncomments range', function()
		vim:set_lines({
			'# a',
			'# b',
			'# c',
		})
		vim.cmd('2,3Uncomment')
		vim:assert_lines({
			'# a',
			'b',
			'c',
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
	test_case(0, 'gccgcc', '1 line uncommented')
	test_case(0, 'gcj', '2 lines commented')
	test_case(0, 'gcjgcj', '2 lines uncommented')
	test_case(1, 'gcc', '')
	test_case(1, 'gcj', '2 lines commented')
	test_case(1, 'gcjgcj', '2 lines uncommented')
	test_case(2, 'gcj', '')
	test_case(9, '3Ggcc', '--No lines to comment--')
end)
