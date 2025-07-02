local vim = create_vim()

describe('context collapse', function()
	local function test_collapse(up, expected)
		test('up ' .. up, function()
			local lines = {}
			for level = 0, 5 do
				for i = 1, 10 do
					table.insert(
						lines,
						('%slevel %d, line %d'):format(('  '):rep(level), level, #lines + 1)
					)
				end
			end

			vim:resize(100, 9)
			vim:set_lines(lines)
			vim:feed('G' .. ('k'):rep(up))

			vim.cmd.ContextEnable()

			local screen = vim:get_screen()
			table.remove(screen, #screen)
			assert.same(expected, screen)
		end)
	end

	test_collapse(0, {
		'level 0, line 10',
		'  level 1, line 20',
		'    level 2, line 30',
		'      level 3, line 40',
		'        level 4, line 50',
		'          level 5, line 59',
		'          level 5, line 60',
		'60,1',
	})

	test_collapse(1, {
		'level 0, line 10',
		'  level 1, line 20',
		'    level 2, line 30',
		'      level 3, line 40',
		'        level 4, line 50',
		'          level 5, line 59',
		'          level 5, line 60',
		'59,1',
	})

	test_collapse(2, {
		'level 0, line 10',
		'  level 1, line 20',
		'      level 3, line 40',
		'        level 4, line 50',
		'          level 5, line 58',
		'          level 5, line 59',
		'          level 5, line 60',
		'58,1',
	})

	test_collapse(3, {
		'level 0, line 10',
		'  level 1, line 20',
		'        level 4, line 50',
		'          level 5, line 57',
		'          level 5, line 58',
		'          level 5, line 59',
		'          level 5, line 60',
		'57,1',
	})

	test_collapse(5, {
		'level 0, line 10',
		'          level 5, line 55',
		'          level 5, line 56',
		'          level 5, line 57',
		'          level 5, line 58',
		'          level 5, line 59',
		'          level 5, line 60',
		'55,1',
	})

	test_collapse(6, {
		'          level 5, line 54',
		'          level 5, line 55',
		'          level 5, line 56',
		'          level 5, line 57',
		'          level 5, line 58',
		'          level 5, line 59',
		'          level 5, line 60',
		'54,1',
	})
end)

describe('context lines', function()
	local function test_contain(yes, cases)
		for _, case in ipairs(cases) do
			test(case, function()
				local lines = {
					'first',
					' ' .. case,
				}
				for i = 1, 10 do
					table.insert(lines, '')
				end
				table.insert(lines, '  last')

				vim:resize(100, 5)
				vim:set_lines(lines)
				vim:feed('G')

				vim.cmd.ContextEnable()

				local screen = vim:get_screen()
				table.remove(screen, #screen)
				table.remove(screen, #screen)
				assert.same(
					yes and { 'first', ' ' .. case, '  last' }
						or { 'first', '', '  last' },
					screen
				)
			end)
		end
	end

	describe('contain', function()
		test_contain(true, {
			'a',
			'b',
			'z',
			'A',
			'B',
			'Z',
			'foo',
			'0',
			'1',
			'9',
			'123',
			'("/foo',
		})
	end)

	describe("don't contain", function()
		test_contain(false, {
			'} foo',
			'] foo',
			') foo',
			'# foo',
		})
	end)
end)

test(':ContextDisable', function()
	vim:resize(100, 4)
	vim:set_lines({ 'a', '  b', '  c' })
	vim:feed('G')

	vim.cmd.ContextEnable()

	assert.same({
		'a',
		'  c',
		'3,1',
		'',
	}, vim:get_screen())

	vim.cmd.ContextDisable()

	assert.same({
		'  b',
		'  c',
		'3,1',
		'',
	}, vim:get_screen())
end)

test("doesn't hang in empty buffer", function()
	vim:set_lines({})
	vim.cmd.ContextEnable()
end)
