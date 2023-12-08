before_each(function()
	package.loaded.commenter = nil
	vim.keymap.set('', 'gc', '<Plug>(commenter)')
	vim.keymap.set('', 'gcc', '<Plug>(commenter-current-line)')
end)

local function assert_lines(expected_lines)
	local got_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	assert.are.same(expected_lines, got_lines)
end

local function feed(keys)
	return vim.api.nvim_feedkeys(keys, 'xtim', true)
end

local function set_lines(lines)
	return vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

describe('toggle single line', function()
	local function case(cms, input, expected_output)
		local function helper(input)
			test(
				string.format("[%s] '%s' -> '%s'", cms, input, expected_output),
				function()
					vim.o.cms = cms
					set_lines({ input })
					feed('gcc')
					assert_lines({ expected_output })
				end
			)
		end

		helper(input)
		helper(string.gsub(input, '%%s', ' %s '))
	end

	case('/*%s*/', 'abc', '/* abc */')
	case('/*%s*/', '/* abc */', 'abc')
	case('/*%s*/', '/*abc*/', 'abc')
	case('/*%s*/', '/*  abc  */', ' abc ')
	case('/*%s*/', '/**//*def*/', '//*def') -- BAD
	case('/*%s*/', '/* *//*def*/', '/*def*/')
	case('/*%s*/', '/*** abc ***/', 'abc')
	case('//%s', '//// abc', 'abc')
	case('#%s', '#  abc ', ' abc ')
	case('--%s', 'abc--def', '-- abc--def')
	case('//%s', '', '')
	case('//%s', ' ', ' ')
end)

describe('toggle multiple lines', function()
	local function case(keys)
		test(keys, function()
			local UNCOMMENTED = {
				'    aaa',
				'',
				'     ',
				'  bbb',
				'\t   ccc',
			}

			local COMMENTED = {
				'  //   aaa',
				'',
				'     ',
				'  // bbb',
				'\t //   ccc',
			}

			vim.o.cms = '//%s'
			set_lines(UNCOMMENTED)
			feed(keys)
			assert_lines(COMMENTED)
			feed(keys)
			assert_lines(UNCOMMENTED)
		end)
	end

	case('4gcc')
	case('gc4j')
	case('4gcj')
end)

describe('toggle mixed lines', function()
	before_each(function()
		vim.o.cms = '*%s'
	end)

	it('should do comment', function()
		set_lines({
			'',
			'aaa*',
			'*bbb',
		})
		feed('2gcc')
		assert_lines({
			'',
			'* aaa*',
			'* *bbb',
		})
	end)

	it('should do uncomment', function()
		set_lines({
			'',
			'* aaa',
			'ccc*',
		})
		feed('2gcc')
		assert_lines({
			'',
			'aaa',
			'ccc*',
		})
	end)
end)

describe('filetype', function()
	before_each(function()
		vim.cmd.filetype({ args = { 'plugin', 'on' } })
	end)

	describe('unset', function()
		before_each(function()
			set_lines({
				'text',
			})
		end)

		test('uses default commentstring', function()
			feed('gcc')
			assert_lines({
				'# text',
			})
		end)

		test('uses custom commentstring', function()
			feed('gcc')
			feed('gcc')
			vim.o.cms = '//%s'
			feed('gcc')
			assert_lines({
				'// text',
			})
		end)
	end)

	describe('known', function()
		before_each(function()
			assert(vim.o.cms == '')
			vim.o.ft = 'c'
			assert(vim.o.cms ~= '')
			set_lines({
				'code',
			})
		end)

		test('uses custom commentstring', function()
			feed('gcc')
			feed('gcc')
			vim.o.cms = 'BLA %s BLA'
			feed('gcc')
			assert_lines({
				'BLA code BLA',
			})
		end)
	end)

	describe('tsx', function()
		before_each(function()
			vim.o.ft = 'typescriptreact'
			set_lines({
				'(',
				'<html/>',
				')',
			})
		end)

		test('guesses ts correctly', function()
			feed('1Ggcc3Ggcc')
			assert_lines({
				'// (',
				'<html/>',
				'// )',
			})
		end)

		test('guesses html correctly', function()
			pending('How to test treesitter?')
			feed('2Ggcc')
			assert_lines({
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
		set_lines({
			'aaa',
			'bbb',
			'* ccc',
		})
		feed('1gcc')
		assert_lines({
			'* aaa',
			'* bbb',
			'* ccc',
		})
		feed('j.')
		assert_lines({
			'* aaa',
			'bbb',
			'ccc',
		})
	end)

	it('works in visual mode', function()
		set_lines({
			'aaa',
			'bbb',
			'* ccc',
		})
		feed('Vjgc')
		assert_lines({
			'* aaa',
			'* bbb',
			'* ccc',
		})
		feed('.')
		assert_lines({
			'* aaa',
			'bbb',
			'ccc',
		})
	end)
end)
