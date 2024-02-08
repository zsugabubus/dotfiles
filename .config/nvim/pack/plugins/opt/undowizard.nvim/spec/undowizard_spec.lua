local function feed(keys)
	vim.api.nvim_feedkeys(keys, 'xtim', true)
end

local function undobreak()
	-- :h undo-break
	vim.o.undolevels = vim.o.undolevels
end

local function enew_paste()
	vim.cmd.enew()
	vim.fn.setline(1, 'x')
	feed('p')
	return vim.fn.getline(1, '$')
end

describe(':Undotree', function()
	test('opens undotree://X', function()
		local target_buf = vim.fn.bufnr()
		vim.cmd.Undotree()
		assert.same(vim.fn.bufname(), string.format('undotree://%d', target_buf))
	end)
end)

describe('undotree://', function()
	local target_buf

	before_each(function()
		target_buf = vim.fn.bufnr()
		vim.fn.setline(1, { '1-1', '2-1' })
		undobreak()
		vim.fn.setline(2, { '2-22', '3-22', '4-22', '5-22', '6-22', '7-22' })
		undobreak()
		vim.fn.setline(3, '3-333')
		vim.fn.setline(7, '7-333')
		vim.cmd.Undotree()
	end)

	test('undo to', function()
		feed('ju')
		assert.same(vim.fn.bufname(), string.format('undotree://%d', target_buf))
		assert.same(
			vim.fn.getbufline(0, 1, '$'),
			{ '1-1', '2-22', '3-22', '4-22', '5-22', '6-22', '7-22' }
		)
		feed('ju')
		assert.same(vim.fn.getbufline(0, 1, '$'), { '1-1', '2-1' })
	end)

	test('preview deletions', function()
		feed('-')
		vim.cmd.buffer(string.format('undo://%d/2', target_buf))
		assert.same(
			vim.fn.getline(1, '$'),
			{ '1-1', '2-22', '3-22', '4-22', '5-22', '6-22', '7-22' }
		)
		feed('gvy')
		assert.same(enew_paste(), { 'x', '3-22', '4-22', '5-22', '6-22', '7-22' })
	end)

	test('preview additions', function()
		feed('+')
		vim.cmd.buffer(string.format('undo://%d/3', target_buf))
		assert.same(
			vim.fn.getline(1, '$'),
			{ '1-1', '2-22', '3-333', '4-22', '5-22', '6-22', '7-333' }
		)
		feed('gvy')
		assert.same(enew_paste(), { 'x', '3-333', '4-22', '5-22', '6-22', '7-333' })
	end)

	test('copy deletions; single hunk', function()
		feed('jy-')
		assert.same(enew_paste(), { 'x', '2-1' })
	end)

	test('copy additions; single hunk', function()
		feed('jy+')
		assert.same(
			enew_paste(),
			{ 'x', '2-22', '3-22', '4-22', '5-22', '6-22', '7-22' }
		)
	end)

	test('copy deletions; multiple hunks', function()
		feed('y-')
		assert.same(enew_paste(), { 'x', '3-22', '4-22', '5-22', '6-22', '7-22' })
	end)

	test('copy additions; multiple hunks', function()
		feed('y+')
		assert.same(enew_paste(), { 'x', '3-333', '4-22', '5-22', '6-22', '7-333' })
	end)

	test('undo diff folded by default', function()
		feed('j')
		assert.is_true(vim.fn.line('.') > 3)
	end)

	test('undo diff toggle', function()
		feed(' j')
		assert.is_same(vim.fn.line('.'), 3)
		feed(' jk')
		assert.is_same(vim.fn.line('.'), 2)
	end)
end)
