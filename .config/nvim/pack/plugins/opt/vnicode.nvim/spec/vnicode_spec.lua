local vim = create_vim({
	isolated = false,
	width = 100,
	height = 5,
	on_setup = function(vim)
		vim.cmd.runtime('plugin/gzip.vim')
		vim.o.cmdheight = 3
		vim:lua(function()
			require('vnicode').setup()
		end)
		vim.keymap.set('', 'ga', '<Plug>(vnicode-unicode)')
		vim.keymap.set('', 'g8', '<Plug>(vnicode-utf8)')
	end,
})

test('ga, visual mode, multi-line', function()
	vim:set_lines({ 'a', 'b' })
	vim:feed('vjga')
	vim:assert_screen()
end)

describe('g8, normal mode:', function()
	local function case(s)
		test(string.format("'%s'", s), function()
			vim:set_lines({ s })
			vim:feed('g8')
			vim:assert_screen()
		end)
	end

	case('')
	case('\r')
	case('a')
	case('ő')
	case('ﬁ')
	case('🌍')
	case('\u{10ffff}')
end)
