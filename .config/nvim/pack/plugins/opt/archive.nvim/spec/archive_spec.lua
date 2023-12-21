local function assert_lines(expected)
	local got = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	assert.are.same(expected, got)
end

local function feed(keys)
	vim.api.nvim_feedkeys(keys, 'xtim', true)
end

local function set_lines(lines)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function system(cmd)
	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		assert.are.same({ vim.v.shell_error, output }, { 0, '' })
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
			assert_lines({ string.sub(c_path, 2) })
		end)

		test(':edit', function()
			system({ 'zip', zip_path, foo_path })
			vim.cmd.edit()
			assert_lines({ string.sub(c_path, 2), string.sub(foo_path, 2) })
		end)

		test('gf', function()
			local bufnr = vim.fn.bufnr()
			feed('gf')
			assert.are_not.same(bufnr, vim.fn.bufnr())
		end)

		test('<CR>', function()
			local bufnr = vim.fn.bufnr()
			feed('\r')
			assert.are_not.same(bufnr, vim.fn.bufnr())
		end)
	end)

	describe('file', function()
		before_each(function()
			feed('gf')
		end)

		test('content', function()
			assert_lines(CONTENT)
		end)

		test('&filetype', function()
			assert.are.same(vim.bo.filetype, 'c')
		end)

		test(':edit', function()
			vim.fn.writefile(OTHER_CONTENT, c_path)
			system({ 'zip', zip_path, c_path })
			vim.cmd.edit()
			assert_lines(OTHER_CONTENT)
		end)

		test(':write', function()
			assert.are.same(vim.bo.buftype, 'nofile')
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
		assert_lines(CONTENT)
	end)

	test('&filetype', function()
		assert.are.same(vim.bo.filetype, 'c')
	end)

	test(':edit', function()
		vim.fn.writefile(OTHER_CONTENT, input_path)
		vim.fn.delete(xz_path)
		system({ 'xz', input_path })
		vim.cmd.edit()
		assert_lines(OTHER_CONTENT)
	end)

	test(':write', function()
		local nvim_echo = spy.on(vim.api, 'nvim_echo')
		set_lines(OTHER_CONTENT)
		assert.True(vim.bo.modified)
		vim.cmd.write()
		assert.False(vim.bo.modified)
		assert.are.same(
			system({ 'xzcat', xz_path }),
			table.concat(OTHER_CONTENT, '\n') .. '\n'
		)
		assert.spy(nvim_echo).was_called_with({
			{
				string.format('"%s" written with xz', xz_path),
				'Normal',
			},
		}, true, {})
	end)
end)
