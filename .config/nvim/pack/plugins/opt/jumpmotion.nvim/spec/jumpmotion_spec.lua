local vim = create_vim(function(vim)
	vim.keymap.set('', 's', '<Plug>(jumpmotion)')
end)

test('X', function()
	vim:set_lines({ '12', '1' })
	vim.api.nvim_input('s1')
	assert.same({
		'a2',
		'b',
		'~',
		'~',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
	vim.api.nvim_input('b')
	assert.same({
		'12',
		'1',
		'~',
		'~',
		'~',
		'2,1',
		'',
	}, vim:get_screen())
end)

test('/', function()
	vim.fn.setreg('/', '1')
	vim:set_lines({ '121', '/' })
	vim.api.nvim_input('s/')
	assert.same({
		'a2b',
		'c',
		'~',
		'~',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
end)

test('fX', function()
	vim:feed('f1')
	vim:set_lines({ '121', ';' })
	vim.api.nvim_input('s;')
	assert.same({
		'a2b',
		'c',
		'~',
		'~',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
end)

test('fX; no previous search', function()
	vim:set_lines({ ';', ';' })
	vim.api.nvim_input('s;')
	assert.same({
		'a',
		'b',
		'~',
		'~',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
end)

test('$', function()
	vim:set_lines({ '1', '$', '$2' })
	vim.api.nvim_input('s$')
	assert.same({
		'1a',
		'b',
		'c2d',
		'~',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
end)

test('normal mode, single target', function()
	vim:set_lines({ 'x', '11' })
	vim:feed('s1rs')
	vim:assert_lines({ 'x', 's1' })
end)

test('visual mode, single target', function()
	vim:set_lines({ 'x', '1' })
	vim:feed('vs1rs')
	vim:assert_lines({ 's', 's' })
end)
