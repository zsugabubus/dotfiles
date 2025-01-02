local vim = create_vim({ isolate = false })

local function enew_paste()
	vim.cmd.enew()
	vim.fn.setline(1, 'x')
	vim:feed('p')
	return vim.fn.getline(1, '$')
end

describe(':Undotree', function()
	it('edits undotree://X of current buffer', function()
		local target_buf = vim.fn.bufnr()
		vim.cmd.Undotree()
		assert.same(('undotree://%d'):format(target_buf), vim.fn.bufname())
	end)
end)

describe('undotree://', function()
	local target_buf

	before_each(function()
		target_buf = vim.fn.bufnr()
		vim.fn.setline(1, { '1-1', '2-1' })
		-- undobreak
		vim.fn.setline(2, { '2-22', '3-22', '4-22', '5-22', '6-22', '7-22' })
		-- undobreak
		vim:lua(function()
			_G.vim.fn.setline(3, '3-333')
			_G.vim.fn.setline(7, '7-333')
		end)
		vim.cmd.Undotree()
	end)

	test('undo to', function()
		vim:feed('ju')
		assert.same(('undotree://%d'):format(target_buf), vim.fn.bufname())
		assert.same(
			{ '1-1', '2-22', '3-22', '4-22', '5-22', '6-22', '7-22' },
			vim.fn.getbufline(0, 1, '$')
		)
		vim:feed('ju')
		assert.same({ '1-1', '2-1' }, vim.fn.getbufline(0, 1, '$'))
	end)

	test('preview deletions', function()
		vim:feed('-')
		vim.cmd.buffer(('undo://%d/2'):format(target_buf))
		assert.same(
			{ '1-1', '2-22', '3-22', '4-22', '5-22', '6-22', '7-22' },
			vim.fn.getline(1, '$')
		)
		vim:feed('gvy')
		assert.same({ 'x', '3-22', '4-22', '5-22', '6-22', '7-22' }, enew_paste())
	end)

	test('preview additions', function()
		vim:feed('+')
		vim.cmd.buffer(('undo://%d/3'):format(target_buf))
		assert.same(
			{ '1-1', '2-22', '3-333', '4-22', '5-22', '6-22', '7-333' },
			vim.fn.getline(1, '$')
		)
		vim:feed('gvy')
		assert.same({ 'x', '3-333', '4-22', '5-22', '6-22', '7-333' }, enew_paste())
	end)

	test('copy deletions; single hunk', function()
		vim:feed('jy-')
		assert.same({ 'x', '2-1' }, enew_paste())
	end)

	test('copy additions; single hunk', function()
		vim:feed('jy+')
		assert.same(
			{ 'x', '2-22', '3-22', '4-22', '5-22', '6-22', '7-22' },
			enew_paste()
		)
	end)

	test('copy deletions; multiple hunks', function()
		vim:feed('y-')
		assert.same({ 'x', '3-22', '4-22', '5-22', '6-22', '7-22' }, enew_paste())
	end)

	test('copy additions; multiple hunks', function()
		vim:feed('y+')
		assert.same({ 'x', '3-333', '4-22', '5-22', '6-22', '7-333' }, enew_paste())
	end)

	test('undo diff folded by default', function()
		assert.same(-1, vim.fn.foldclosedend(1))
		assert.same(11, vim.fn.foldclosedend(2))
		assert.same(21, vim.fn.foldclosedend(12))
		assert.same(26, vim.fn.foldclosedend(22))
		assert.same(-1, vim.fn.foldclosedend(27))
		assert.same(vim.fn.line('$'), 27)
		vim:feed('zr')
		for i = 1, vim.fn.line('$') do
			assert.same(-1, vim.fn.foldclosedend(i))
		end
	end)

	test('undo diff toggle', function()
		vim:feed(' j')
		assert.same(3, vim.fn.line('.'))
		vim:feed(' jk')
		assert.same(2, vim.fn.line('.'))
	end)
end)

test('undo:// ignores modeline', function()
	vim:set_lines({ ' vim: a' })
	vim.cmd.Undotree()
	vim:feed('y+')
	assert.same('', vim.v.errmsg)
	vim:feed('+')
	assert.same('', vim.v.errmsg)
end)

describe(':Undodiff', function()
	it('opens diff against the original text without arguments', function()
		vim.cmd.enew()
		local buf = vim.fn.bufnr()
		vim:set_lines({})

		vim.cmd.Undodiff()

		assert.same(buf, vim.fn.bufnr())
		assert.True(vim.wo.diff)

		vim.cmd.wincmd('p')

		assert.same(('undo://%d/0'):format(buf), vim.fn.bufname())
		assert.True(vim.wo.diff)
	end)

	it('opens diff against a specifc change with {number}', function()
		vim.cmd.enew()
		local buf = vim.fn.bufnr()
		vim:set_lines({})
		vim:set_lines({ 'x' })

		vim.cmd.Undodiff('1')

		vim.cmd.wincmd('p')
		assert.same(('undo://%d/1'):format(buf), vim.fn.bufname())
	end)
end)
