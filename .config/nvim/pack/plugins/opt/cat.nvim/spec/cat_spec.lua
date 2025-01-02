local vim = create_vim({ isolate = false, height = 10 })

local function cat(s)
	return 'cat://' .. s:gsub('[a-zA-Z.]+', vim.fn.bufnr)
end

local function split_chars(s)
	return _G.vim.split(s, '')
end

describe(':Cat', function()
	before_each(function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir)
		vim.fn.chdir(dir)
		vim.fn.writefile({}, 'a.bak')
		vim.fn.writefile({}, 'a.c')
		vim.fn.mkdir('a.dir')
		vim.fn.writefile({}, 'b.txt')
	end)

	it('completes files', function()
		assert.same(
			{ 'a.bak', 'a.c', 'a.dir/' },
			vim.fn.getcompletion('Cat a', 'cmdline')
		)
	end)

	it('narrows to expanded paths', function()
		vim.o.wildignore = '*.bak'
		vim.cmd.edit('b.txt')
		vim.cmd('Cat a* %')
		assert.same(cat('a.c,a.dir,b.txt'), vim.fn.bufname())
	end)

	it('uses filetype of the first buffer', function()
		vim.cmd('Cat a.c b.txt')
		assert.same('c', vim.bo.filetype)
	end)
end)

describe(':CatArgs', function()
	it('narrows to argv paths', function()
		vim.cmd.args('A C B')
		vim.cmd('CatArgs')
		assert.same(cat('A,C,B'), vim.fn.bufname())
	end)
end)

describe(':Narrow', function()
	it('narrows to the current line without range', function()
		vim.cmd.edit('A')
		vim:set_lines({ '1', '2' })
		vim.cmd('Narrow')
		assert.same(cat('A:1-1'), vim.fn.bufname())
	end)

	it('narrows to the given range', function()
		vim.cmd.edit('A')
		vim:set_lines({ '1', '2' })
		vim.cmd('1,2Narrow')
		assert.same(cat('A:1-2'), vim.fn.bufname())
	end)

	it('uses filetype of the current buffer', function()
		vim.cmd.edit('a.c')
		vim.cmd('Narrow')
		assert.same('c', vim.bo.filetype)
	end)

	it(
		'allows returning to the original buffer after write with buffer #',
		function()
			vim.cmd.edit('A')
			vim.cmd('1Narrow')
			vim:set_lines({ '1', '2' })
			vim.cmd.write()
			vim.cmd.buffer('#')
			assert.same('A', vim.fn.bufname())
		end
	)
end)

describe('cat://', function()
	it('has modeline disabled', function()
		vim.cmd.edit('A')
		vim.cmd.edit(cat('A'))
		assert.False(vim.bo.modeline)
	end)

	it('has swapfile disabled', function()
		vim.cmd.edit('A')
		vim.cmd.edit(cat('A'))
		assert.False(vim.bo.swapfile)
	end)

	it('is readonly iff any of the ranges are readonly', function()
		vim.cmd.edit('A')
		vim.cmd.edit('B')
		vim.cmd.edit('C')
		vim.cmd.edit(cat('A,B:1-1,C'))
		assert.False(vim.bo.readonly)

		vim.fn.setbufvar('B', '&readonly', true)
		vim.cmd.edit()
		assert.True(vim.bo.readonly)

		vim.fn.setbufvar('B', '&readonly', false)
		vim.cmd.edit()
		assert.False(vim.bo.readonly)
	end)

	it('is modifiable iff all of the ranges are modifiable', function()
		vim.cmd.edit('A')
		vim.cmd.edit('B')
		vim.cmd.edit('C')
		vim.cmd.edit(cat('A,B:1-1,C'))
		assert.True(vim.bo.modifiable)

		vim.fn.setbufvar('B', '&modifiable', false)
		vim.cmd.edit()
		assert.False(vim.bo.modifiable)

		vim.fn.setbufvar('B', '&modifiable', true)
		vim.cmd.edit()
		assert.True(vim.bo.modifiable)
	end)

	it('uses filetype of the first range', function()
		vim.cmd.edit('A')
		vim.bo.filetype = 'a'
		vim.cmd.edit('B')
		vim.bo.filetype = 'b'
		vim.cmd.edit(cat('A,B'))
		assert.same('a', vim.bo.filetype)
	end)

	it('has empty undo history after :read', function()
		vim.cmd.edit('A')
		vim:set_lines({ 'a' })
		vim.cmd.edit('B')
		vim:set_lines({ 'b' })
		vim.cmd.edit(cat('A,B'))
		vim.cmd.undo()
		assert.same({ 'a', 'b' }, vim.fn.getline(1, '$'))
		assert.same(-123456, vim.bo.undolevels)
	end)

	it('shows buffer names iff there are multiple ranges', function()
		vim.cmd.edit('A')
		vim:set_lines({ 'a', 'a' })
		vim.cmd.edit('B')
		vim:set_lines({ 'b' })

		vim.cmd.edit(cat('A,B'))
		vim:feed('zb')
		assert.same(
			{ 'A', 'a', 'a', 'B', 'b', '~', '~', '~', '1,1', '' },
			vim:get_screen()
		)

		vim.cmd.file(cat('A'))
		vim.cmd.edit()
		vim:feed('zb')
		assert.same(
			{ 'a', 'a', '~', '~', '~', '~', '~', '~', '1,1', '' },
			vim:get_screen()
		)
	end)

	it('respects insert before first range with single range', function()
		vim.cmd.edit('A')
		vim:set_lines({ '2' })
		vim.cmd.edit(cat('A'))
		vim:feed('O1')
		vim.cmd.write()
		assert.same({ '1', '2' }, vim.fn.getbufline('A', 1, '$'))
		vim.cmd.edit()
		assert.same({ '1', '2' }, vim.fn.getline(1, '$'))
	end)

	it('ignores insert before first range with multiple ranges', function()
		vim.cmd.edit('A')
		vim:set_lines({ '1', 'x', '2' })
		vim.cmd.edit(cat('A:1-1,A:3-3'))
		vim:feed('O0')
		vim.cmd.write()
		assert.same({ '1', 'x', '2' }, vim.fn.getbufline('A', 1, '$'))
		vim.cmd.edit()
		assert.same({ '1', '2' }, vim.fn.getline(1, '$'))
	end)

	it('extends upper range when inserting between ranges', function()
		vim.cmd.edit('A')
		vim:set_lines({ '1', 'x', '3' })
		vim.cmd.edit(cat('A:1-1,A:3-3'))
		vim:feed('o2')
		vim.cmd.write()
		assert.same({ '1', '2', 'x', '3' }, vim.fn.getbufline('A', 1, '$'))
		vim.cmd.edit()
		assert.same({ '1', '2', '3' }, vim.fn.getline(1, '$'))
	end)

	it('allows editing empty range', function()
		vim.cmd.edit('A')
		vim:set_lines({ '>', '<' })
		vim.cmd.edit(cat('A:2-1'))
		vim:set_lines({ 'new' })
		vim.cmd.write()
		assert.same({ '>', 'new', '<' }, vim.fn.getbufline('A', 1, '$'))
		vim.cmd.edit()
		assert.same({ 'new' }, vim.fn.getline(1, '$'))
	end)

	it('allows editing multiple ranges', function()
		vim.cmd.edit('A')
		vim:set_lines(split_chars('aaaaaa   b<-->c    d'))
		vim.cmd.edit(cat('A:1-10,A:15-20'))
		-- Make all uppercase.
		vim:feed('gUG')
		-- Delete `A`s.
		vim:feed('1Gd5G')
		-- Add `C`s.
		vim:feed('6G2oC')
		vim.cmd.write()
		assert.same(
			split_chars('A   B<-->CCC    D'),
			vim.fn.getbufline('A', 1, '$')
		)
		vim.cmd.edit()
		assert.same(split_chars('A   BCCC    D'), vim.fn.getline(1, '$'))
	end)

	it('leaves buffer unmodified when nothing changed', function()
		vim.cmd.edit('A')
		vim:set_lines({ 'x' })
		vim.bo.modified = false
		vim.cmd.edit(cat('A'))
		vim.cmd.write()
		assert.same(0, vim.fn.getbufvar('A', '&modified'))
	end)

	it('fails writing overlapping ranges', function()
		vim.cmd.edit('A')
		vim:set_lines({ '1', '2', '3', '4' })
		vim.cmd.edit('B')
		vim:set_lines({ '1', '2', '3', '4' })

		local function test_case(s)
			vim.cmd.edit(cat(s))
			return assert.same('nowrite', vim.bo.buftype)
		end

		test_case('A,B,A')
		test_case('A,B,A:1-1')
		test_case('A:1-1,B,A:1-1')
		test_case('A:1-1,B,A:1-2')
		test_case('A:2-3,B,A:1-2')
		test_case('A:2-2,B,A:1-3')
	end)

	it('does not report zero changes', function()
		vim.cmd.edit('A')
		vim.cmd.edit(cat('A'))
		vim.cmd.write()
		vim:assert_messages('')
	end)

	it('reports single change', function()
		vim.cmd.edit('A')
		vim.cmd.edit(cat('A'))
		vim:set_lines({ '1', '2', '3' })
		vim.cmd.write()
		vim:assert_messages('1 change written')
	end)

	it('reports multiple changes', function()
		vim.cmd.edit('A')
		vim:set_lines(split_chars('xx'))
		vim.cmd.edit(cat('A'))
		vim:set_lines(split_chars('aaxxbb'))
		vim.cmd.write()
		vim:assert_messages('2 changes written')
	end)

	it('keeps alternative file', function()
		vim.cmd.edit('A')
		vim.cmd.edit(cat('A:1-1'))
		vim:set_lines({ '1', '2', '3' })
		vim.cmd.write()
		assert.same(cat('A:1-3'), vim.fn.bufname())
		assert.same('A', vim.fn.expand('#'))
	end)
end)
