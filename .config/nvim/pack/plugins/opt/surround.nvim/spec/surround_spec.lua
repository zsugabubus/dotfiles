local function assert_lines(expected)
	local got = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	assert.are.same(expected, got)
end

local function feed(keys)
	vim.api.nvim_feedkeys(keys, 'xtim', true)
end

local function set_lines(lines)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

before_each(function()
	vim.keymap.set('x', 's', '<Plug>(surround)')
end)

describe('text', function()
	local function case(input, keys)
		local function template(a, b)
			return (string.gsub(string.gsub(input, '<', a), '>', b))
		end

		assert(not string.find(input, 'X'))

		test(keys, function()
			-- Set line without markers.
			set_lines({ template('', '') })

			feed(keys)

			-- Makers are there.
			assert_lines({ template("'", "'") })

			-- In normal mode and cursor sits at the right end.
			feed('rX')
			assert_lines({ template("'", 'X') })

			-- Visual selection is correct.
			feed('gvd')
			assert_lines({ (string.gsub(input, '<.*>', '')) })
		end)
	end

	describe('singe-byte', function()
		describe('empty', function()
			case('<>', "vs'")
		end)

		describe('single', function()
			case('<a>bc', "vs'")
		end)

		describe('double', function()
			case('<ab>c', "vls'")
			case('a<bc>', "lvls'")
		end)

		describe('double, reversed', function()
			case('<ab>c', "lvhs'")
			case('a<bc>', "llvhs'")
		end)

		describe('wide', function()
			case('<abc>.', "vt.s'")
		end)
	end)

	describe('multi-byte', function()
		describe('single', function()
			case('<ﬁ>xme', "vs'")
		end)

		describe('double', function()
			case('<ﬁx>më', "vls'")
			case('ﬁ<xm>ë', "lvls'")
			case('ﬁx<më>', "llvls'")
		end)

		describe('double, reversed', function()
			case('<ﬁx>më', "lvhs'")
			case('ﬁ<xm>ë', "llvhs'")
			case('ﬁx<më>', "lllvhs'")
		end)

		describe('wide', function()
			case('<ﬁxmë>.', "vt.s'")
		end)
	end)

	test('multi-line', function()
		set_lines({ 'a', 'b', '.' })
		feed("Vjsc'")
		assert_lines({ "'", 'a', 'b', "'", '.' })
		feed('rX')
		assert_lines({ "'", 'a', 'X', "'", '.' })
	end)
end)

describe('map', function()
	local function case(map, expected_charwise, expected_linewise)
		describe(vim.inspect(map), function()
			test('charwise', function()
				set_lines({ '_' })
				feed('vs' .. map)
				assert_lines(expected_charwise)
			end)

			if expected_linewise then
				test('single-line', function()
					set_lines({ '_' })
					feed('Vs' .. map)
					assert_lines({ expected_linewise[1], '_', expected_linewise[2] })
				end)

				test('multi-line', function()
					set_lines({ '>', 'a', 'b', 'c', '<' })
					feed('jVjjs' .. map)
					assert_lines({
						'>',
						expected_linewise[1],
						'a',
						'b',
						'c',
						expected_linewise[2],
						'<',
					})
				end)
			end
		end)
	end

	case('cO', { 'O_O' }, { 'O', 'O' })
	case('|', { '|_|' }, { '|', '|' })
	case('\r', { '', '_', '' }, { '', '' })

	case(')', { '(_)' }, { '(', ')' })
	case('(', { '( _ )' }, { '( ', ' )' })
	case(']', { '[_]' }, { '[', ']' })
	case('[', { '[ _ ]' }, { '[ ', ' ]' })
	case('}', { '{_}' }, { '{', '}' })
	case('{', { '{ _ }' }, { '{ ', ' }' })
	case('>', { '<_>' }, { '<', '>' })

	case('"', { '"_"' }, { '"""', '"""' })
	case("'", { "'_'" }, { "'''", "'''" })
	case('`', { '`_`' }, { '```', '```' })

	case('<div\n', { '<div>_</div>' }, { '<div>', '</div>' })
end)
