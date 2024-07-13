local vim = create_vim({ height = 8 })

describe('fold()', function()
	local function assert_fold(context, expected_screen)
		vim:lua(function(n)
			require('searchfold').fold({ context = n })
		end, context)

		local screen = vim:get_screen()
		-- cmdline
		table.remove(screen)
		-- statusline
		table.remove(screen)
		return assert.same(expected_screen, screen)
	end

	it('works', function()
		vim.o.fillchars = 'fold: '
		vim.o.foldtext = '"(folded)"'
		vim.fn.setreg('/', 'a')

		vim:set_lines({})
		assert_fold(0, { '', '~', '~', '~', '~', '~' })

		vim:set_lines({ '1', '2' })
		assert_fold(0, { '(folded)', '~', '~', '~', '~', '~' })

		vim:set_lines({ '1', '2', '3a' })
		assert_fold(0, { '(folded)', '3a', '~', '~', '~', '~' })
		assert_fold(1, { '1', '2', '3a', '~', '~', '~' })
		assert_fold(3, { '1', '2', '3a', '~', '~', '~' })

		vim:set_lines({ '1a', '2', '3' })
		assert_fold(0, { '1a', '(folded)', '~', '~', '~', '~' })
		assert_fold(1, { '1a', '2', '3', '~', '~', '~' })
		assert_fold(3, { '1a', '2', '3', '~', '~', '~' })

		vim:set_lines({ '1a', '2a' })
		assert_fold(0, { '1a', '2a', '~', '~', '~', '~' })

		vim:set_lines({ '1a', '2', '3a' })
		assert_fold(0, { '1a', '2', '3a', '~', '~', '~' })

		vim:set_lines({ '1a', '2', '3', '4', '5a' })
		assert_fold(1, { '1a', '2', '3', '4', '5a', '~' })

		vim:set_lines({ '1a', '2', '3', '4', '5', '6a' })
		assert_fold(0, { '1a', '(folded)', '6a', '~', '~', '~' })
		assert_fold(1, { '1a', '2', '(folded)', '5', '6a', '~' })
		assert_fold(2, { '1a', '2', '3', '4', '5', '6a' })
	end)
end)
