local vim = create_vim({ width = 200 })

describe('dir', function()
	test('edit', function()
		local dir = vim.fn.tempname()
		local a = dir .. '/a'
		local ac = a .. '/c'
		local b = dir .. '/b'
		local d = dir .. '/d'
		vim.fn.mkdir(ac, 'p')
		vim.fn.mkdir(d, 'p')
		vim.fn.writefile({}, b)

		vim.cmd.edit(dir)
		assert.same('directory', vim.bo.filetype)
		vim:assert_lines({ a .. '/', b, d .. '/' })

		vim.cmd.file(dir .. '//')
		vim:assert_lines({ a .. '/', ac .. '/', b, d .. '/' })

		assert.error_matches(function()
			vim.cmd.write()
		end, 'Cannot write')
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
