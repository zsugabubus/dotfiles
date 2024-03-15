local vim = create_vim({
	isolate = false,
	on_setup = function(vim)
		vim.keymap.set('x', 's', '<Plug>(surround)')
	end,
})

describe('text', function()
	local function case(input, keys)
		local function template(a, b)
			return (string.gsub(string.gsub(input, '<', a), '>', b))
		end

		assert(not string.find(input, 'X'))

		test(keys, function()
			-- Set line without markers.
			vim:set_lines({ template('', '') })

			vim:feed(keys)

			-- Makers are there.
			vim:assert_lines({ template("'", "'") })

			-- In normal mode and cursor sits at the right end.
			vim:feed('rX')
			vim:assert_lines({ template("'", 'X') })

			-- Visual selection is correct.
			vim:feed('gvd')
			vim:assert_lines({ (string.gsub(input, '<.*>', '')) })
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
		vim:set_lines({ 'a', 'b', '.' })
		vim:feed("Vjsc'")
		vim:assert_lines({ "'", 'a', 'b', "'", '.' })
		vim:feed('rX')
		vim:assert_lines({ "'", 'a', 'X', "'", '.' })
	end)
end)

describe('map', function()
	local function case(map, expected_charwise, expected_linewise)
		describe(vim.inspect(map), function()
			test('charwise', function()
				vim:set_lines({ '_' })
				vim:feed('vs' .. map)
				vim:assert_lines(expected_charwise)
			end)

			if expected_linewise then
				test('single-line', function()
					vim:set_lines({ '_' })
					vim:feed('Vs' .. map)
					vim:assert_lines({ expected_linewise[1], '_', expected_linewise[2] })
				end)

				test('multi-line', function()
					vim:set_lines({ '>', 'a', 'b', 'c', '<' })
					vim:feed('jVjjs' .. map)
					vim:assert_lines({
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
