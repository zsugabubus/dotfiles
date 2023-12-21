local function feed(keys)
	vim.api.nvim_feedkeys(keys, 'xtim', true)
end

assert:register('matcher', 'chunk_text', function(_, arguments)
	local expected = unpack(arguments)
	return function(value)
		local actual = table.concat(vim.tbl_map(function(x)
			return x[1]
		end, value))
		-- error(actual)
		return actual == expected
	end
end)

before_each(function()
	-- Buffers are cleaned up so cache must be gone.
	package.loaded['vnicode.data'] = nil
	require('vnicode').setup({
		-- data_dir = '/tmp',
	})
	vim.cmd.runtime('plugin/gzip.vim')
end)

local function set_lines(lines)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

test('ga, visual mode, multi-line', function()
	set_lines({ 'a', 'b' })
	local nvim_echo = spy.on(vim.api, 'nvim_echo')
	feed('vjga')
	assert.spy(nvim_echo).was_called_with(
		match.chunk_text([[< a >97, U+0061, Ll/LATIN SMALL LETTER A
< ^J >10, U+000A, Cc/EOL (<control>)
< b >98, U+0062, Ll/LATIN SMALL LETTER B]]),
		false,
		match.is_table()
	)
end)

describe('g8, normal mode:', function()
	local function case(s, expected)
		test(string.format("'%s'", s), function()
			set_lines({ s })
			local nvim_echo = spy.on(vim.api, 'nvim_echo')
			feed('g8')
			assert
				.spy(nvim_echo)
				.was_called_with(match.chunk_text(expected), false, match.is_table())
		end)
	end

	case('', '(nothing to show)')
	case('\r', '< ^M >13, U+000D, 0x0D, Cc/CR (<control>)')
	case('a', '< a >97, U+0061, 0x61, Ll/LATIN SMALL LETTER A')
	case(
		'ő',
		'< ő >337, U+0151, 0xC5 0x91, Ll/LATIN SMALL LETTER O WITH DOUBLE ACUTE = < o >+< ◌̋ >'
	)
	case(
		'ﬁ',
		'< ﬁ >64257, U+FB01, 0xEF 0xAC 0x81, Ll/LATIN SMALL LIGATURE FI = < f >+< i >'
	)
	case(
		'🌍',
		'< 🌍 >127757, U+1F30D, 0xF0 0x9F 0x8C 0x8D, So/EARTH GLOBE EUROPE-AFRICA'
	)
	case(
		'\u{10ffff}',
		'< <10ffff> >1114111, U+10FFFF, 0xF4 0x8F 0xBF 0xBF, Cn/NO NAME'
	)
end)
