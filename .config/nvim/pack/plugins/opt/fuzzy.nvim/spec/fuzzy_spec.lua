local vim = create_vim({ isolate = false })

local function wait()
	vim.wait(50)
end

local dir

before_each(function()
	dir = vim.fn.tempname()

	vim.fn.mkdir(dir)
	vim.fn.chdir(dir)
end)

describe(':FuzzyFiles', function()
	it('opens and closes picker correctly', function()
		local win = vim.fn.winnr()

		vim.cmd.edit('alt')
		vim.cmd.edit('cur')

		vim.fn.writefile({}, 'c')
		vim.wait(10)
		vim.fn.writefile({}, 'a')
		vim.wait(10)
		vim.fn.writefile({}, 'b')

		vim.cmd.FuzzyFiles()
		wait()

		assert.same(win, vim.fn.winnr())
		assert.same('Select file', vim.fn.bufname())
		vim:assert_lines({
			'>',
			'[3/3]',
			'b',
			'a',
			'c',
		})
		assert.False(vim.wo.number)
		assert.False(vim.wo.relativenumber)

		vim.api.nvim_input('<C-c>')
		wait()

		assert.same('cur', vim.fn.expand('%'))
		assert.same('alt', vim.fn.expand('#'))
	end)

	it('auto-selects only file', function()
		local s = 'new\r\n % # * $(false) ` "'
		vim.fn.writefile({}, s)

		vim.cmd.FuzzyFiles()
		wait()

		assert.same(s, vim.fn.bufname())
	end)

	it('handles deleted buffers without errors', function()
		vim.cmd.edit('a')
		local a = vim.fn.bufnr()
		vim.cmd.edit('b')
		local b = vim.fn.bufnr()

		vim.cmd.FuzzyFiles()
		vim.cmd.bwipeout(tostring(a))
		vim.cmd.bwipeout(tostring(b))
		wait()

		assert.same('', vim.v.errmsg)
	end)
end)

describe(':FuzzyBuffers', function()
	it('opens and closes picker correctly', function()
		local win = vim.fn.winnr()

		local unnamed = vim.fn.bufnr()
		vim.bo.modified = true

		vim.cmd.edit('nobuflisted')
		vim.bo.buflisted = false

		vim.cmd.edit('recent')
		local recent = vim.fn.bufnr()
		vim.wait(1000)

		vim.cmd.edit('cur')

		vim.cmd.FuzzyBuffers()
		wait()

		assert.same(win, vim.fn.winnr())
		assert.same('Select buffer', vim.fn.bufname())
		vim:assert_lines({
			'>',
			'[2/2]',
			string.format('%3d     recent', recent),
			string.format('%3d  +  [No Name]', unnamed),
			'~',
		})

		vim.api.nvim_input('<C-c>')
		wait()

		assert.same('cur', vim.fn.expand('%'))
		assert.same('recent', vim.fn.expand('#'))
	end)

	it('auto-selects only buffer', function()
		vim.cmd.edit('nobuflisted')
		vim.bo.buflisted = false
		vim.cmd.edit('other')
		vim.cmd.edit('cur')

		vim.cmd.FuzzyBuffers()
		wait()

		assert.same('other', vim.fn.bufname())
	end)
end)

describe(':FuzzyTags', function()
	before_each(function()
		vim.fn.writefile({ 'x' }, 'foo.txt')
		vim.fn.writefile({ 'x' }, 'bar.txt')
		vim.fn.writefile({ 'y' }, 'baz.txt')
		vim.fn.writefile({
			'X\tfoo.txt\t/x',
			'X\tbar.txt\t/x',
			'Y\tbaz.txt\t/y',
		}, 'tags')
	end)

	it('opens and closes picker correctly', function()
		local win = vim.fn.winnr()

		vim.cmd.edit('alt')
		vim.cmd.edit('cur')

		vim.cmd.FuzzyTags()
		wait()

		assert.same(win, vim.fn.winnr())
		assert.same('Select tag', vim.fn.bufname())
		vim:assert_lines({
			'>',
			'[3/3]',
			'X       foo.txt',
			'X       bar.txt',
			'Y       baz.txt',
		})

		vim.api.nvim_input('<C-c>')
		wait()

		assert.same('cur', vim.fn.expand('%'))
		assert.same('alt', vim.fn.expand('#'))
	end)

	it('can select tag', function()
		vim.cmd.FuzzyTags()
		wait()
		vim.api.nvim_input('<CR>')
		wait()
		assert.same('foo.txt', vim.fn.bufname())

		vim.cmd.FuzzyTags()
		wait()
		vim.api.nvim_input('<Down><CR>')
		wait()
		assert.same('bar.txt', vim.fn.bufname())

		vim.cmd.FuzzyTags()
		wait()
		vim.api.nvim_input('<Down><Down><CR>')
		wait()
		assert.same('baz.txt', vim.fn.bufname())
	end)
end)
