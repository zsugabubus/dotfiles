before_each(function()
	package.loaded.commenter = nil
	vim.keymap.set('', 'gc', '<Plug>(commenter)')
	vim.keymap.set('', 'gcc', '<Plug>(commenter-current-line)')
end)

local function assert_lines(expected_lines)
	local got_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	assert.are.same(expected_lines, got_lines)
end

local function feedkeys(keys)
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
					feedkeys('gcc')
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
	case('--%s', 'abc--def', 'abcdef')
	case('--%s', 'abc--def--ghi', 'abcdef--ghi')
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
			feedkeys(keys)
			assert_lines(COMMENTED)
			feedkeys(keys)
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
		feedkeys('2gcc')
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
		feedkeys('2gcc')
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

	describe('tsx', function()
		before_each(function()
			vim.o.ft = 'typescriptreact'
			set_lines({
				'(',
				'<html/>',
				')',
			})
		end)

		test('ts', function()
			feedkeys('1Ggcc3Ggcc')
			assert_lines({
				'// (',
				'<html/>',
				'// )',
			})
		end)

		test('x', function()
			pending('How to test treesitter?')
			feedkeys('2Ggcc')
			assert_lines({
				'(',
				'{/* <html/> */}',
				')',
			})
		end)
	end)
end)
