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

local function case_modes(init_lhs, lhs, input, expected)
	test('visual mode', function()
		set_lines(input)
		feed(init_lhs)
		feed(string.format('v%sd', lhs))
		assert_lines(expected)
	end)

	test('operator-pending mode', function()
		set_lines(input)
		feed(init_lhs)
		feed(string.format('d%s', lhs))
		assert_lines(expected)
	end)
end

describe('ii', function()
	local function trim_XO(s)
		return string.sub(s, 2)
	end

	local function is_X(s)
		return string.sub(s, 1, 1) == 'X'
	end

	local function not_XO(s)
		return string.sub(s, 1, 1) == ' '
	end

	local function case(lines)
		local input = vim.tbl_map(trim_XO, lines)
		local expected = vim.tbl_map(trim_XO, vim.tbl_filter(not_XO, lines))

		for X, line in ipairs(lines) do
			if is_X(line) then
				describe(X .. 'G', function()
					case_modes(X .. 'G', 'ii', input, expected)
				end)
			end
		end
	end

	case({
		'X.',
		'Xa',
		'X.',
		' ',
	})

	case({
		' .',
		'X a',
		'o  b',
		'o   c',
		'o  d',
		'X e',
		'o  f',
		' .',
	})

	case({
		'  a',
		'X  b',
		'o   c',
		'X  d',
		'  e',
		'   f',
	})

	case({
		'   a',
		'X   b',
		'   c',
	})

	case({
		' .',
		'o',
		'X   a',
		'X ',
		'X',
		'X   b',
		'o ',
		' .',
	})
end)

do
	local function case(lhs, input, expected)
		describe(lhs, function()
			case_modes('', lhs, input, expected)
		end)
	end

	case('il', { ' x x ', '.' }, { '  ', '.' })
	case('al', { ' x x ', '.' }, { '', '.' })
end
