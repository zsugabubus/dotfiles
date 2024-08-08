local vim = create_vim({ height = 10 })

test(':Copen and :Cclose', function()
	local function f()
		if vim.fn.bufwinnr('qf://0') == -1 then
			return 'hidden'
		end
		if vim.fn.bufname() == 'qf://0' then
			return 'current'
		end
		return 'visible'
	end
	vim.cmd.Copen()
	assert.same('current', f())
	vim.cmd.Copen()
	assert.same('current', f()) -- :copen from quickfix.
	vim.cmd.enew()
	assert.same('hidden', f()) -- Double :copen does not open twice.
	vim.cmd.Copen()
	assert.same('current', f())
	vim.cmd('vsplit new')
	assert.same('visible', f())
	vim.cmd.Copen()
	assert.same('current', f()) -- Quickfix visible but open from other.
	vim.cmd.Cclose()
	assert.same('hidden', f())
	vim.cmd.Cclose()
	assert.same('hidden', f()) -- Double :cclose.
	vim.cmd.Copen()
	vim.cmd.tabnew()
	assert.same('hidden', f())
	vim.cmd.Copen()
	assert.same('current', f()) -- Across tabs.
	vim.cmd.Cclose()
	assert.same('hidden', f())
end)

test(':Cclose on quit', function()
	vim.cmd.Copen()
	vim.cmd.wincmd('p')
	assert.True(vim.fn.winnr('$') == 2)
	assert.error_matches(function()
		vim.cmd.wincmd('q')
	end, 'Invalid channel')
end)

test(':Qstack', function()
	vim.cmd.Qstack()
	assert.same('qf://', vim.fn.bufname())
end)

describe('qf://', function()
	test('read empty', function()
		vim.cmd.edit('qf://')
		assert.same('qfstack', vim.bo.filetype)
		vim:assert_lines({ '' })
	end)

	test('read', function()
		vim.fn.setqflist({ {} })
		vim.fn.setqflist({}, 'f')
		vim.fn.setqflist({}, ' ', { title = ' vim: foo' })
		vim.fn.setqflist({}, ' ', { title = 'current' })
		vim.cmd.edit('qf://')
		vim:assert_lines({
			'qf://2\t vim: foo',
			'qf://3\tcurrent',
		})
		vim:assert_cursor('qf://', 2, 1)
	end)

	test('write empty', function()
		local function f()
			return vim.fn.getqflist({ nr = '$' }).nr
		end
		vim.cmd.edit('qf://')
		vim.fn.setqflist({ {} })
		vim.fn.setqflist({ {} })
		assert.same(2, f())
		vim.cmd.write()
		assert.same(0, f())
		vim:assert_messages('')
	end)

	test('CR', function()
		vim.fn.setqflist({}, ' ', { title = 'foo', items = { { text = 'foo' } } })
		vim.fn.setqflist({}, ' ', { title = 'bar', items = { { text = 'bar' } } })
		vim.cmd.edit('qf://')
		vim:assert_cursor('qf://', 2, 1)
		assert.same(2, vim.fn.getqflist({ id = 0 }).id)
		vim:feed('gg\r')
		assert.same(1, vim.fn.getqflist({ id = 0 }).id)
		vim:assert_messages('error list 1 of 2; 1 errors       foo')
		assert.same('qf://1', vim.fn.bufname())
		vim:assert_lines({ '|| foo' })
	end)
end)

test(':Qf', function()
	vim.cmd.Qf()
	assert.same('qf://0', vim.fn.bufname())

	vim.cmd.Qf({ count = 1 })
	assert.same('qf://1', vim.fn.bufname())

	vim.cmd.Qf('2')
	assert.same('qf://2', vim.fn.bufname())
end)

test('qf://X', function()
	vim.cmd.edit('a')
	local a = vim.fn.bufnr()
	vim:set_lines({ '1234' })

	vim.fn.setqflist({
		{ text = '' },
		{ text = ' \t\t vim: a' },
		{ bufnr = a, text = 'b' },
		{ bufnr = a, lnum = 1, text = 'c' },
		{ bufnr = a, lnum = 1, col = 2, text = 'd' },
		{ bufnr = a, lnum = 1, col = 2, end_col = 3, text = 'e' },
	})
	local original = vim.fn.getqflist()

	vim.cmd.edit('qf://0')
	vim:assert_lines({
		'|| ',
		'|| vim: a',
		'a|| b',
		'a|1| c',
		'a|1 col 2| d',
		'a|1 col 2-3| e',
	})

	vim:feed('GddggP')
	vim:assert_lines({
		'a|1 col 2-3| e',
		'|| ',
		'|| vim: a',
		'a|| b',
		'a|1| c',
		'a|1 col 2| d',
	})
	assert.not_same(-1, vim.fn.bufwinnr('qf://0'))
	vim:feed('\r')
	-- Quickfix item opened in separate window.
	assert.not_same(-1, vim.fn.bufwinnr('qf://0'))
	vim:assert_cursor('a', 1, 2)
	assert.same({
		original[6],
		original[1],
		original[2],
		original[3],
		original[4],
		original[5],
	}, vim.fn.getqflist())
	vim:assert_messages('')
end)

describe('qf://X', function()
	local A = {
		'|| a',
		'|| b',
		'a.a|1| a',
		'b.b|1| a',
	}

	local B = {
		'|| a',
		'|| b',
		'a.a|1| b',
		'b.b|1| b',
	}

	local FA = {
		'|| a',
		'|| b',
		'a.a|1| a',
		'a.a|1| b',
	}

	local FB = {
		'|| a',
		'|| b',
		'b.b|1| a',
		'b.b|1| b',
	}

	before_each(function()
		vim.cmd.edit('a.a')
		local a = vim.fn.bufnr()
		vim.cmd.edit('b.b')
		local b = vim.fn.bufnr()

		vim.fn.setqflist({
			{ text = 'a' },
			{ text = 'b' },
			{ bufnr = a, lnum = 1, text = 'a' },
			{ bufnr = a, lnum = 1, text = 'b' },
			{ bufnr = b, lnum = 1, text = 'a' },
			{ bufnr = b, lnum = 1, text = 'b' },
		}, 'r')

		vim.cmd.edit('qf://0')
		vim:assert_lines({
			'|| a',
			'|| b',
			'a.a|1| a',
			'a.a|1| b',
			'b.b|1| a',
			'b.b|1| b',
		})

		vim.fn.setreg('/', 'a')
	end)

	after_each(function()
		vim.cmd.write()
		assert.same(vim.fn.line('$'), #vim.fn.getqflist())
	end)

	test(':global', function()
		vim.cmd('g//d')
		vim:assert_lines({
			'|| b',
			'b.b|1| b',
		})
	end)

	test(':G', function()
		vim.cmd('G')
		vim:assert_lines(A)
	end)

	test(':G {pat}', function()
		vim.cmd('G b')
		vim:assert_lines(B)
	end)

	test(':G!', function()
		vim.cmd('G! b')
		vim:assert_lines(A)
	end)

	test(':V', function()
		vim.cmd('V')
		vim:assert_lines(B)
	end)

	test(':V {pat}', function()
		vim.cmd('V b')
		vim:assert_lines(A)
	end)

	test(':V!', function()
		vim.cmd('V! b')
		vim:assert_lines(B)
	end)

	test(':Gf', function()
		vim.cmd('Gf')
		vim:assert_lines(FA)
	end)

	test(':Gf {glob}', function()
		vim.cmd('Gf *.a')
		vim:assert_lines(FA)
	end)

	test(':Gf!', function()
		vim.cmd('Gf!')
		vim:assert_lines(FB)
	end)

	test(':Vf', function()
		vim.cmd('Vf')
		vim:assert_lines(FB)
	end)

	test(':Vf {glob}', function()
		vim.cmd('Vf *.a')
		vim:assert_lines(FB)
	end)

	test(':Vf!', function()
		vim.cmd('Vf!')
		vim:assert_lines(FA)
	end)

	test('df', function()
		vim:feed('4Gdf')
		vim:assert_lines(FB)
		assert.same(3, vim.fn.line('.'))
		vim:feed('.')
		vim:assert_lines({
			'|| a',
			'|| b',
		})
	end)
end)

test(':Cnext is fast', function()
	local items = {}
	for i = 1, 10000 do
		table.insert(items, { buf = 0, lnum = i, text = '' })
	end
	vim.fn.setqflist(items)

	vim.cmd.Qedit()
	vim.cmd.Copen()
	assert.True(vim.fn.bufwinnr('qf://0') > 0)
	assert.True(vim.fn.bufwinnr('qe://0') > 0)

	for i = 1, 100 do
		vim.cmd.Cnext()
	end
	assert.same(101, vim.fn.getqflist({ idx = 0 }).idx)
end)

test(':vimgrep workflow', function()
	vim.cmd.edit('a.txt')
	vim:set_lines({ 'abba', '\t abc' })

	vim.cmd('silent vimgrep /b\\+/g a.txt')

	assert.same({
		'a.txt|1 col 2-4| abba',
		'a.txt|2 col 4-5| abc',
	}, vim:get_lines('qf://0'))

	assert.same({ 1, 1 }, vim:get_cursor('qf://0'))
	vim:assert_cursor('a.txt', 1, 2)

	vim.cmd.Cnext()
	assert.same(2, vim.fn.getqflist({ idx = 0 }).idx)
	assert.same({ 2, 1 }, vim:get_cursor('qf://0'))
	vim:assert_cursor('a.txt', 2, 4)
	assert.False(vim.bo[vim.fn.bufnr('qf://0')].modified)

	vim:assert_messages('')
	vim.cmd.Cnext()
	vim:assert_messages('E553: No more items')

	vim.cmd.Copen()
	vim:feed('ggddp')
	assert.same({ 2, 1 }, vim:get_cursor('qf://0'))
	vim.cmd.write()
	assert.same({ 1, 1 }, vim:get_cursor('qf://0'))

	vim.cmd.Cnext()
	vim:assert_cursor('a.txt', 1, 2)
	vim:assert_messages('')
end)

test(':grep workflow', function()
	vim.go.grepprg = 'echo'

	vim.cmd('silent grep a.txt:1:2:foo')
	assert.same({
		'a.txt|1 col 2| foo',
	}, vim:get_lines('qf://0'))

	vim.cmd('silent grep bar')
	assert.same({
		'|| bar',
	}, vim:get_lines('qf://0'))
end)

test(':Qedit', function()
	vim.cmd.Qedit()
	assert.same('qe://0', vim.fn.bufname())

	vim.cmd.Qedit({ count = 1 })
	assert.same('qe://1', vim.fn.bufname())

	vim.cmd.Qedit('2')
	assert.same('qe://2', vim.fn.bufname())

	vim.cmd.Qf('3')
	vim.cmd.Qe()
	assert.same('qe://3', vim.fn.bufname())

	vim.cmd.Qf('3')
	vim.cmd.Qe('4')
	assert.same('qe://4', vim.fn.bufname())
end)

describe('qe://X', function()
	local a, b, c

	before_each(function()
		vim.cmd.edit('a')
		a = vim.fn.bufnr()
		vim:set_lines({ ' vim: a1', 'a2' })
		vim.bo.modified = false

		vim.cmd.edit('b')
		b = vim.fn.bufnr()
		vim:set_lines({ 'b1', 'b2', 'b3' })
		vim.bo.modified = false

		vim.cmd.edit('c')
		c = vim.fn.bufnr()
		vim:set_lines({ 'c1' })
		vim.bo.modified = false

		vim.fn.setqflist({
			{},
			{ bufnr = b, lnum = 2 },
			{ bufnr = c, lnum = 1, col = 1, end_col = 2, text = 'x' },
			{ bufnr = a, lnum = 2, col = 3 },
			{ bufnr = a, lnum = 1 },
			{ bufnr = a, lnum = 2 },
			{ bufnr = a, lnum = 2, col = 2 },
		})

		vim.cmd.edit('qe://0')
	end)

	test('screen', function()
		-- Ordered alphabetically, no duplicated lines.
		assert.same({
			'a|1|  vim: a1',
			'a|2| a2',
			'b|2| b2',
			'c|1| c1',
			'~',
			'~',
			'~',
			'~',
			'1,2',
			'',
		}, vim:get_screen())

		vim:feed('0ineo')
		assert.same('a|1| neo vim: a1', vim:get_screen()[1])

		vim:feed('ccneovim')
		assert.same('a|1| neovim', vim:get_screen()[1])
	end)

	test('write no changes', function()
		vim.bo.modified = true
		vim.cmd.update()
		assert.False(vim.bo.modified)

		assert.False(vim.bo[a].modified)
		assert.False(vim.bo[b].modified)
		assert.False(vim.bo[c].modified)

		vim:assert_messages('--No changes--')
	end)

	test('write single change', function()
		vim:feed('1G0Cfoo')
		vim.cmd.messages('clear')

		assert.True(vim.bo.modified)
		vim.cmd.update()
		assert.False(vim.bo.modified)

		assert.same({ 'foo', 'a2' }, vim:get_lines('a'))
		assert.True(vim.bo[a].modified)
		assert.False(vim.bo[b].modified)
		assert.False(vim.bo[c].modified)

		vim:assert_messages('1 line changed in 1 buffer')
	end)

	test('write multiple changes', function()
		vim:feed('1G0Cfoo')
		vim:feed('2G0Cbar')
		vim.cmd.messages('clear')

		assert.True(vim.bo.modified)
		vim.cmd.update()
		assert.False(vim.bo.modified)

		assert.same({ 'foo', 'bar' }, vim:get_lines('a'))
		assert.True(vim.bo[a].modified)
		assert.False(vim.bo[b].modified)
		assert.False(vim.bo[c].modified)

		vim:assert_messages('2 lines changed in 1 buffer')
	end)

	test('write multiple buffers', function()
		vim:feed('1G0Cfoo')
		vim:feed('2G0Cbar')
		vim:feed('3Gcc')
		vim.cmd.messages('clear')

		assert.True(vim.bo.modified)
		vim.cmd.update()
		assert.False(vim.bo.modified)

		assert.same({ 'foo', 'bar' }, vim:get_lines('a'))
		assert.same({ 'b1', '', 'b3' }, vim:get_lines('b'))
		assert.True(vim.bo[a].modified)
		assert.True(vim.bo[b].modified)
		assert.False(vim.bo[c].modified)

		vim:assert_messages('3 lines changed in 2 buffers')
	end)

	test('delete lines', function()
		vim.cmd.v('/^c1$/d')
		vim:feed('Cfoo')
		assert.same({
			'c|1| foo',
			'~',
			'~',
			'~',
			'~',
			'~',
			'~',
			'~',
			'1,3',
			'',
		}, vim:get_screen())
		vim.cmd.messages('clear')

		assert.True(vim.bo.modified)
		vim.cmd.update()
		assert.False(vim.bo.modified)

		assert.same({ 'foo' }, vim:get_lines('c'))
		assert.False(vim.bo[a].modified)
		assert.False(vim.bo[b].modified)
		assert.True(vim.bo[c].modified)

		vim:assert_messages('1 line changed in 1 buffer')

		vim.cmd.undo()
		vim.cmd.undo()
		vim.cmd.echo()
		vim.cmd.messages('clear')
		assert.same({
			'a|1|  vim: a1',
			'a|2| a2',
			'b|2| b2',
			'c|1| c1',
			'~',
			'~',
			'~',
			'~',
			'1,2',
			'',
		}, vim:get_screen())

		assert.True(vim.bo.modified)
		vim.cmd.update()
		assert.False(vim.bo.modified)

		assert.same({ 'c1' }, vim:get_lines('c'))
		assert.False(vim.bo[a].modified)
		assert.False(vim.bo[b].modified)
		assert.True(vim.bo[c].modified)

		vim:assert_messages('1 line changed in 1 buffer')
	end)

	test('quickfix change', function()
		vim.bo.modified = true
		vim:assert_lines({ ' vim: a1', 'a2', 'b2', 'c1' })

		vim.cmd.Copen()
		vim:feed('3dd')
		vim.cmd.write()

		vim.cmd.wincmd('p')
		vim:assert_lines({ ' vim: a1', 'a2' })
		assert.False(vim.bo.modified)
	end)
end)

test('qe://X :Qcontext', function()
	vim:set_lines({ '1', '2', '3', '4' })
	local buf = vim.fn.bufnr()

	vim.fn.setqflist({
		{ bufnr = buf, lnum = 1 },
		{ bufnr = buf, lnum = 2 },
	})

	vim.cmd.Qedit()

	vim.cmd('2Qcontext')
	assert.same({
		'|1| 1',
		'2',
		'3',
		'',
		'1',
		'|2| 2',
		'3',
		'4',
		'1,1',
		'',
	}, vim:get_screen())

	vim.cmd('999Qcontext')
	assert.same({
		'|1| 1',
		'2',
		'3',
		'4',
		'',
		'1',
		'|2| 2',
		'3',
		'1,1',
		'',
	}, vim:get_screen())

	vim.cmd.Qcontext()
	assert.same({
		'|1| 1',
		'|2| 2',
		'~',
		'~',
		'~',
		'~',
		'~',
		'~',
		'1,1',
		'',
	}, vim:get_screen())
end)
