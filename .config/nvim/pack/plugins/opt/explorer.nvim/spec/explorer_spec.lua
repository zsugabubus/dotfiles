local vim = create_vim({ width = 200 })

local function tempname()
	return vim.fn.tempname()
		.. [[$PATH $(false) * % # | <cword> vim: a 'b" `false`]]
end

describe('dir', function()
	test('non-directory', function()
		local function f()
			return vim.bo.filetype == 'directory'
		end

		local dir = tempname()
		vim.fn.mkdir(dir, 'p')

		vim.cmd.edit(vim.fn.fnameescape(dir))
		assert.True(f())

		local a = dir .. '/a'
		vim.fn.writefile({}, a)
		vim.cmd.edit(vim.fn.fnameescape(a))
		assert.False(f())

		vim.cmd.edit(vim.fn.fnameescape(dir .. '/newfile'))
		assert.False(f())
	end)

	test('edit', function()
		local dir = tempname()
		local a = dir .. '/a'
		local ac = a .. '/c'
		local acc = ac .. '/c'
		local b = dir .. '/b'
		local d = dir .. '/d'
		vim.fn.mkdir(acc, 'p')
		vim.fn.mkdir(d, 'p')
		vim.fn.writefile({}, b)

		vim.cmd.edit(vim.fn.fnameescape(dir))
		assert.same('directory', vim.bo.filetype)
		vim:assert_lines({ a .. '/', b, d .. '/' })

		vim.cmd.file(vim.fn.fnameescape(dir .. '//'))
		vim:assert_lines({ a .. '/', ac .. '/', acc .. '/', b, d .. '/' })

		assert.error_matches(function()
			vim.cmd.write()
		end, 'Cannot write')
	end)

	test(':chdir', function()
		local dir = vim.fn.tempname()
		local a = dir .. '/a'
		vim.fn.mkdir(a, 'p')

		vim.cmd.edit(dir)
		vim:assert_lines({ a .. '/' })

		vim.fn.chdir(dir)
		vim:assert_lines({ 'a/' })
	end)

	test('<Plug>(explorer-goto-parent)', function()
		local dir = tempname()
		local a = dir .. '/a'
		local ab = a .. '/b'
		vim.fn.mkdir(ab, 'p')

		vim.keymap.set('', 's', '<Plug>(explorer-goto-parent)')
		vim.cmd.edit(vim.fn.fnameescape(ab))

		vim:feed('s')
		assert.same(a, vim.fn.bufname())

		vim:feed('s')
		assert.same(dir, vim.fn.bufname())
	end)

	test('<Plug>(explorer-recursive)', function()
		local dir = tempname()
		vim.fn.mkdir(dir, 'p')

		vim.keymap.set('', 's', '<Plug>(explorer-recursive)')
		vim.cmd.edit(vim.fn.fnameescape(dir))
		local bufnr = vim.fn.bufnr()

		vim:feed('s')
		assert.same(bufnr, vim.fn.bufnr())
		assert.same(dir .. '//', vim.fn.bufname())

		vim:feed('s')
		assert.same(dir .. '//', vim.fn.bufname())
	end)
end)

describe('http', function()
	local function mock_curl(response)
		local dir = vim.fn.tempname()
		local bin = dir .. '/curl'
		vim.fn.mkdir(dir)
		vim.fn.writefile({
			'#!/bin/sh -eu',
			'printf %s ' .. vim.fn.shellescape(response),
		}, bin)
		vim.fn.setfperm(bin, 'r-x------')
		vim.fn.setenv('PATH', string.format('%s:%s', dir, vim.fn.getenv('PATH')))
	end

	test('edit', function()
		vim.cmd.edit(vim.fn.fnameescape('https://example.com#[1-10000]'))
		assert.True(vim.fn.search('Example Domain') > 0)

		assert.error_matches(function()
			vim.cmd.write()
		end, 'Cannot write')
	end)

	test('filetype', function()
		local function test_case(url, filetype)
			vim.cmd.edit(vim.fn.fnameescape(url))
			return assert.same(filetype, vim.bo.filetype)
		end

		mock_curl('<!doctype html>')

		test_case('http://a.c', 'html')
		test_case('http://b.c/', 'html')
		test_case('http://0.0.0.0//a.c', 'c')
		test_case('http://0.0.0.0/a.json?/a.c', 'json')
		test_case('http://0.0.0.0/a.json#/a.c', 'json')
	end)
end)

describe('ssh', function()
	local function mock_ssh()
		local dir = vim.fn.tempname()
		local bin = dir .. '/ssh'
		vim.fn.mkdir(dir)
		vim.fn.writefile({
			'#!/bin/sh -eu',
			'test "$1" = "--"; shift',
			'test "$1" = "localhost"; shift',
			'test "$#" = 1',
			'exec sh -c "$1"',
		}, bin)
		vim.fn.setfperm(bin, 'r-x------')
		vim.fn.setenv('PATH', string.format('%s:%s', dir, vim.fn.getenv('PATH')))
	end

	local ssh = 'ssh://localhost'
	local root

	before_each(function()
		mock_ssh()
		root = tempname()
		vim.fn.mkdir(root)
	end)

	test('dir', function()
		local a = root .. '/a'
		local ac = root .. '/a/c'
		local b = root .. '/b'
		vim.fn.mkdir(ac, 'p')
		vim.fn.writefile({}, b)

		vim.cmd.edit(vim.fn.fnameescape(ssh .. root))
		vim:assert_lines({
			ssh .. a .. '/',
			ssh .. b,
		})
		assert.same('directory', vim.bo.filetype)

		vim.cmd.edit(vim.fn.fnameescape(ssh .. root .. '//'))
		vim:assert_lines({
			ssh .. root .. '/',
			ssh .. a,
			ssh .. ac,
			ssh .. b,
		})
		assert.same('directory', vim.bo.filetype)

		assert.error_matches(function()
			vim.cmd.write()
		end, 'Cannot write')
	end)

	describe('file', function()
		local f

		before_each(function()
			f = root .. '/a.c'
		end)

		test('edit', function()
			vim.fn.writefile({ 'original', 'content', '' }, f)

			vim.cmd.edit(vim.fn.fnameescape(ssh .. f))
			vim:assert_lines({ 'original', 'content', '' })
			assert.same('c', vim.bo.filetype)

			vim.fn.setfperm(f, '---------')
			assert.error_matches(function()
				vim.fn.writefile({ '' }, f)
			end, 'writing: permission denied')

			vim:set_lines({ 'new', 'content', '' })
			assert.True(vim.bo.modified)
			vim.cmd.write()
			assert.False(vim.bo.modified)
			vim:assert_messages(string.format('"%s" 3L, 13B written on localhost', f))
			assert.same({ 'new', 'content', '' }, vim.fn.readfile(f))
		end)

		test('new', function()
			vim.cmd.edit(vim.fn.fnameescape(ssh .. f))
			vim:set_lines({ 'content' })
			vim.cmd.write()
			vim:assert_messages(
				string.format('"%s" [New] 1L, 8B written on localhost', f)
			)
			assert.same({ 'content' }, vim.fn.readfile(f))
		end)

		test('readonly', function()
			vim.fn.writefile({ '' }, f)

			vim.fn.setfperm(f, 'r--------')
			vim.cmd.edit(vim.fn.fnameescape(ssh .. f))
			assert.True(vim.bo.readonly)

			vim.fn.setfperm(f, 'rw-------')
			vim.cmd.edit()
			assert.False(vim.bo.readonly)
		end)

		test('read error', function()
			vim.fn.writefile({ '' }, f)
			vim.fn.setfperm(f, '---------')
			vim.cmd.edit(vim.fn.fnameescape(ssh .. f))
			vim:assert_messages(
				string.format(
					"Can't read file: cat: %s: Permission denied",
					vim.fn.shellescape(f)
				)
			)
			assert.True(vim.bo.readonly)
		end)

		test('write error', function()
			vim.cmd.edit(vim.fn.fnameescape(ssh .. f))
			vim.fn.setfperm(root, '---------')
			vim.o.cmdheight = 5
			vim.bo.modified = true
			vim.cmd.write()
			assert.True(vim.bo.modified)
		end)
	end)

	test('other', function()
		vim.cmd.edit(vim.fn.fnameescape(ssh .. '/dev/zero'))
		assert.True(vim.bo.readonly)
		vim:assert_messages('')

		assert.error_matches(function()
			vim.cmd.write()
		end, 'Cannot write')
	end)
end)
