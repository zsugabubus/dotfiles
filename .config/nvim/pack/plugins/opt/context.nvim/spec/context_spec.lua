local vim = create_vim()

local function collapse(up, expected)
	test('context collapse; line ' .. (60 - up), function()
		local lines = {}
		for level = 0, 5 do
			for i = 1, 10 do
				table.insert(
					lines,
					string.format(
						'%slevel %d, line %d',
						string.rep('  ', level),
						level,
						#lines + 1
					)
				)
			end
		end

		vim:resize(100, 9)
		vim:set_lines(lines)
		vim:feed('G' .. string.rep('k', up))

		vim.cmd.ContextEnable()

		local screen = vim:get_screen()
		table.remove(screen, #screen)
		assert.same(expected, screen)
	end)
end

collapse(0, {
	'level 0, line 10',
	'  level 1, line 20',
	'    level 2, line 30',
	'      level 3, line 40',
	'        level 4, line 50',
	'          level 5, line 59',
	'          level 5, line 60',
	'60,1',
})

collapse(1, {
	'level 0, line 10',
	'  level 1, line 20',
	'    level 2, line 30',
	'      level 3, line 40',
	'        level 4, line 50',
	'          level 5, line 59',
	'          level 5, line 60',
	'59,1',
})

collapse(2, {
	'level 0, line 10',
	'  level 1, line 20',
	'      level 3, line 40',
	'        level 4, line 50',
	'          level 5, line 58',
	'          level 5, line 59',
	'          level 5, line 60',
	'58,1',
})

collapse(3, {
	'level 0, line 10',
	'  level 1, line 20',
	'        level 4, line 50',
	'          level 5, line 57',
	'          level 5, line 58',
	'          level 5, line 59',
	'          level 5, line 60',
	'57,1',
})

collapse(5, {
	'level 0, line 10',
	'          level 5, line 55',
	'          level 5, line 56',
	'          level 5, line 57',
	'          level 5, line 58',
	'          level 5, line 59',
	'          level 5, line 60',
	'55,1',
})

collapse(6, {
	'          level 5, line 54',
	'          level 5, line 55',
	'          level 5, line 56',
	'          level 5, line 57',
	'          level 5, line 58',
	'          level 5, line 59',
	'          level 5, line 60',
	'54,1',
})

test('line ignore', function()
	local lines = {}
	table.insert(lines, 'first')

	for i = 1, 10 do
		table.insert(lines, '')
	end

	table.insert(lines, ' ignored')

	table.insert(lines, '  middle')

	table.insert(lines, '  : ignored')
	table.insert(lines, '  { ignored')
	table.insert(lines, '  } ignored')
	table.insert(lines, '  ( ignored')
	table.insert(lines, '  ) ignored')
	table.insert(lines, '  [ ignored')
	table.insert(lines, '  ] ignored')
	table.insert(lines, '  0 ignored')
	table.insert(lines, '   ignored')

	for i = 1, 10 do
		table.insert(lines, '')
	end

	table.insert(lines, '    last')

	vim:resize(100, 5)
	vim:set_lines(lines)
	vim:feed('G')

	vim.cmd.ContextEnable()

	local screen = vim:get_screen()
	table.remove(screen, #screen)
	table.remove(screen, #screen)
	assert.same({
		'first',
		'  middle',
		'    last',
	}, screen)
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
