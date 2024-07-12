local vim = create_vim(function(vim)
	vim.keymap.set('', 's', '<Plug>(jumpmotion)')
end)

test('literal', function()
	local function test_case(c)
		vim:set_lines({ '', 'x' .. c })
		vim:feed('s' .. c .. 'rs')
		return vim:assert_lines({ '', 'xs' })
	end

	test_case('1')
	test_case('\\')
	test_case('+')
	test_case('(')
end)

test('/ with empty pattern', function()
	vim:set_lines({ '', 'x///' })
	vim:feed('s/rs')
	vim:assert_lines({ '', 'xs//' })
end)

test('/ with non-empty pattern', function()
	local function test_case(pattern)
		vim.fn.setreg('/', pattern)
		vim:set_lines({ '', 'x1' })
		vim:feed('s/rs')
		return vim:assert_lines({ '', 'xs' })
	end

	test_case('1')
	test_case('\\v1')
	test_case('\\V1')
end)

test('; without previous search', function()
	vim:set_lines({ '', 'x;;;' })
	vim:feed('s;rs')
	vim:assert_lines({ '', 'xs;;' })
end)

test('; with previous search', function()
	local function test_case(c)
		vim:feed('f' .. c)
		vim:set_lines({ '', 'x' .. c .. c .. c })
		vim:feed('s;rs')
		return vim:assert_lines({ '', 'xs' .. c .. c })
	end

	test_case('1')
	test_case('\\')
	test_case('+')
	test_case('(')
end)

test('$', function()
	vim.o.virtualedit = 'all'
	vim:set_lines({ '', 'x$x' })
	vim:feed('s$ars')
	vim:assert_lines({ '', 'xsx' })
	vim:feed('ggs$rs')
	vim:assert_lines({ '', 'xsxs' })
end)

test('target ignored under cursor', function()
	vim:set_lines({ '1', 'x1' })
	vim:feed('s1rs')
	vim:assert_lines({ '1', 'xs' })
	vim:feed('s1rs')
	vim:assert_lines({ 's', 'xs' })
end)

test('targets ignored in closed fold; open-closed', function()
	vim.o.fillchars = 'fold: '
	vim.o.foldtext = '"(folded)"'
	vim:set_lines({ '', '1', '1', '1' })
	vim.cmd('1,2fold|3,4fold|1foldopen')
	vim:feed('Gs1rs')
	assert.same({
		'',
		's',
		'(folded)',
		'~',
		'~',
		'2,1',
		'',
	}, vim:get_screen())
end)

test('targets ignored in closed fold; closed-open', function()
	vim.o.fillchars = 'fold: '
	vim.o.foldtext = '"(folded)"'
	vim:set_lines({ '1', '1', '1', '' })
	vim.cmd('1,2fold|3,4fold|3foldopen')
	vim:feed('s1rs')
	assert.same({
		'(folded)',
		's',
		'',
		'~',
		'~',
		'3,1',
		'',
	}, vim:get_screen())
end)

test('offscreen targets ignored', function()
	vim:resize(25, 7)
	vim.o.wrap = false
	local s = string.rep('a', 1000)
	vim:set_lines({ s, s, s, s, s, s, s })
	-- Remove onscreen "a"s.
	vim:feed('500|2Gg0\x16g$6Gr ')
	-- Except one at the center.
	vim:feed('4G500|ra')
	vim:feed('sars')
	assert.same({
		'',
		'',
		'            s',
		'',
		'',
		'4,500',
		'',
	}, vim:get_screen())
end)

test('pick target in normal mode', function()
	vim:resize(25, 15)
	vim:set_lines({ 'bar >*<', '>*<' })
	vim.cmd.split('enew')
	vim:set_lines({ 'foo >*<', '>*<' })
	vim.cmd.split()
	vim.api.nvim_input('$s*')
	assert.same({
		'foo >a<',
		'>b<',
		'~',
		'~',
		'1,7',
		'foo >c<',
		'>d<',
		'~',
		'~',
		'1,1',
		'bar >e<',
		'>f<',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
	vim.api.nvim_input('drs')
	assert.same({
		'foo >*<',
		'>s<',
		'~',
		'~',
		'1,7',
		'foo >*<',
		'>s<',
		'~',
		'~',
		'2,2',
		'bar >*<',
		'>*<',
		'~',
		'1,1',
		'',
	}, vim:get_screen())
end)

test('pick target in visual mode', function()
	vim:resize(25, 15)
	vim:set_lines({ 'bar >*<', '>*<' })
	vim.cmd.split('enew')
	vim:set_lines({ 'foo >*<', '>*<' })
	vim.cmd.split()
	vim.api.nvim_input('$vs*')
	assert.same({
		'foo >a<',
		'>b<',
		'~',
		'~',
		'1,7',
		'foo >c<',
		'>d<',
		'~',
		'~',
		'1,1',
		'bar >*<',
		'>*<',
		'~',
		'1,1',
		'-- VISUAL --  1',
	}, vim:get_screen())
	vim.api.nvim_input('drv')
	assert.same({
		'foo >*v',
		'vv<',
		'~',
		'~',
		'1,7',
		'foo >*v',
		'vv<',
		'~',
		'~',
		'1,7',
		'bar >*<',
		'>*<',
		'~',
		'1,1',
		'',
	}, vim:get_screen())
end)

test('labels; nowrap', function()
	vim:resize(27, 7)
	vim.o.wrap = false
	local s = string.rep('.', 100)
	vim:set_lines({ s, s })
	vim.fn.setreg('/', '.')
	vim.api.nvim_input('s/')
	assert.same({
		'.abcdefghijklmnopqrstuvwxyz',
		'aaaaaaaaaaaaaaaaaaaaaaaaabb',
		'~',
		'~',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
	vim.api.nvim_input('a')
	assert.same({
		'.a.........................',
		'bcdefghijklmnopqrstuvwxyz..',
		'~',
		'~',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
	vim.api.nvim_input('a')
	assert.same({
		'...........................',
		'...........................',
		'~',
		'~',
		'~',
		'1,2',
		'',
	}, vim:get_screen())
end)

test('labels; wrap', function()
	vim:resize(27, 7)
	vim:set_lines({ string.rep('.', 52) })
	vim.fn.setreg('/', '.')
	vim.api.nvim_input('s/')
	assert.same({
		'.abcdefghijklmnopqrstuvwxyz',
		'aaaaaaaaaaaaaaaaaaaaaaaaaz',
		'~',
		'~',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
end)

test('window close', function()
	vim:set_lines({ 'x1x1' })
	vim.cmd.split('enew')
	vim:set_lines({ 'x1x1' })
	vim.api.nvim_input('s1a')
	vim.cmd.close()
	vim.api.nvim_input('s1ars')
	vim:assert_lines({ 'xsx1' })
end)

test('empty line after right offscreen', function()
	vim.o.wrap = false
	vim:set_lines({ string.rep(' ', 1000) .. 'a', '' })
	vim.api.nvim_input('sa')
	assert.same({
		'',
		'',
		'~',
		'~',
		'~',
		'1,1',
		'jumpmotion: No matches',
	}, vim:get_screen())
	vim:assert_messages('')
end)

test('interrupt', function()
	vim:set_lines({ 'x1x1' })
	vim.api.nvim_input('s1')
	assert.same({
		'xaxb',
		'~',
		'~',
		'~',
		'~',
		'1,1',
		'jumpmotion:',
	}, vim:get_screen())
	vim.api.nvim_input('<C-C>')
	assert.same({
		'x1x1',
		'~',
		'~',
		'~',
		'~',
		'1,1',
		'',
	}, vim:get_screen())
	vim:assert_messages('')
end)
