local vim = create_vim({ isolate = false })

local function system(cmd)
	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		assert.same({ 0, '' }, { vim.v.shell_error, output })
	end
	return output
end

local CONTENT = { 'foo', 'bar', 'baz' }
local OTHER_CONTENT = { 'hello world' }

describe('zip', function()
	local c_path
	local foo_path
	local zip_path

	before_each(function()
		local prefix = vim.fn.tempname()
		c_path = prefix .. '.c'
		foo_path = prefix .. 'foo'
		zip_path = prefix .. '.zip'

		vim.fn.writefile(CONTENT, c_path)
		vim.fn.writefile({}, foo_path)

		system({ 'zip', zip_path, c_path })

		vim.cmd.edit(vim.fn.fnameescape(zip_path))
	end)

	describe('list', function()
		test('rendered', function()
			vim:assert_lines({ string.sub(c_path, 2) })
		end)

		test(':edit', function()
			system({ 'zip', zip_path, foo_path })
			vim.cmd.edit()
			vim:assert_lines({ string.sub(c_path, 2), string.sub(foo_path, 2) })
		end)

		test('gf', function()
			local bufnr = vim.fn.bufnr()
			vim:feed('gf')
			assert.are_not.same(bufnr, vim.fn.bufnr())
		end)

		test('<CR>', function()
			local bufnr = vim.fn.bufnr()
			vim:feed('\r')
			assert.are_not.same(bufnr, vim.fn.bufnr())
		end)
	end)

	describe('file', function()
		before_each(function()
			vim:feed('gf')
		end)

		test('content', function()
			vim:assert_lines(CONTENT)
		end)

		test('&filetype', function()
			assert.same('c', vim.bo.filetype)
		end)

		test(':edit', function()
			vim.fn.writefile(OTHER_CONTENT, c_path)
			system({ 'zip', zip_path, c_path })
			vim.cmd.edit()
			vim:assert_lines(OTHER_CONTENT)
		end)

		test(':write', function()
			assert.same('nofile', vim.bo.buftype)
			assert.has.error(vim.cmd.write)
		end)
	end)
end)

describe('xz', function()
	local input_path
	local xz_path

	before_each(function()
		local prefix = vim.fn.tempname()
		input_path = prefix .. '.c'
		xz_path = input_path .. '.xz'

		vim.fn.writefile(CONTENT, input_path)
		system({ 'xz', input_path })

		vim.cmd.edit(vim.fn.fnameescape(xz_path))
	end)

	test('content', function()
		vim:assert_lines(CONTENT)
	end)

	test('&filetype', function()
		assert.same('c', vim.bo.filetype)
	end)

	test(':edit', function()
		vim.fn.writefile(OTHER_CONTENT, input_path)
		vim.fn.delete(xz_path)
		system({ 'xz', input_path })
		vim.cmd.edit()
		vim:assert_lines(OTHER_CONTENT)
	end)

	test(':write', function()
		vim:set_lines(OTHER_CONTENT)
		assert.True(vim.bo.modified)
		vim.cmd.write()
		assert.False(vim.bo.modified)
		assert.same(
			table.concat(OTHER_CONTENT, '\n') .. '\n',
			system({ 'xzcat', xz_path })
		)
		vim:assert_messages(string.format('"%s" written with xz', xz_path))
	end)
end)
