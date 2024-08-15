local vim = create_vim({ isolate = false, width = 200 })

local function system(cmd)
	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		assert.same({ 0, '' }, { vim.v.shell_error, output })
	end
	return output
end

local CONTENT = { 'foo', 'bar', 'baz' }
local OTHER_CONTENT = { 'hello world' }

local function tempname()
	return vim.fn.tempname() .. [[$PATH $(false) '"` % * # vim: a |]]
end

describe('zip', function()
	local c_path
	local foo_path
	local zip_path

	local function edit_deleted_archive()
		it(':edit shows stderr when archive does not exist', function()
			vim.fn.delete(zip_path)
			vim.cmd.edit()
			assert.matches('cannot find or open', vim.fn.getline(1))
			assert.same('nofile', vim.bo.buftype)
			assert.same('', vim.bo.filetype)
			assert.False(vim.bo.modeline)
		end)
	end

	before_each(function()
		local prefix = tempname()
		c_path = prefix .. '.c'
		foo_path = prefix .. 'foo'
		zip_path = prefix .. '.zip'

		vim.cmd.edit(vim.fn.fnameescape(zip_path))

		vim.fn.writefile(CONTENT, c_path)
		vim.fn.writefile({}, foo_path)
		system({ 'zip', zip_path, c_path })

		vim.cmd.edit()
	end)

	describe('list view', function()
		it('shows correct members', function()
			vim:assert_lines({ string.sub(c_path, 2) })
			assert.same('nofile', vim.bo.buftype)
			assert.same('archive', vim.bo.filetype)
			assert.False(vim.bo.modeline)
		end)

		it(':edit reloads members', function()
			system({ 'zip', zip_path, foo_path })
			vim.cmd.edit()
			vim:assert_lines({ string.sub(c_path, 2), string.sub(foo_path, 2) })
		end)

		edit_deleted_archive()

		it('gf goes to member', function()
			local bufnr = vim.fn.bufnr()
			vim:feed('gf')
			assert.are_not.same(bufnr, vim.fn.bufnr())
		end)

		it('<CR> goes to member', function()
			local bufnr = vim.fn.bufnr()
			vim:feed('\r')
			assert.are_not.same(bufnr, vim.fn.bufnr())
		end)
	end)

	describe('member view', function()
		before_each(function()
			vim:feed('gf')
		end)

		it('shows correct content', function()
			vim:assert_lines(CONTENT)
			assert.same('nofile', vim.bo.buftype)
			assert.same('c', vim.bo.filetype)
			assert.True(vim.bo.modeline)
		end)

		it(':edit reloads content', function()
			vim.fn.writefile(OTHER_CONTENT, c_path)
			system({ 'zip', zip_path, c_path })
			vim:assert_lines(CONTENT)
			vim.cmd.edit()
			vim:assert_lines(OTHER_CONTENT)
		end)

		edit_deleted_archive()
	end)
end)

describe('xz', function()
	local input_path
	local xz_path

	before_each(function()
		local prefix = tempname()
		input_path = prefix .. '.c'
		xz_path = input_path .. '.xz'

		vim.cmd.edit(vim.fn.fnameescape(xz_path))

		vim.fn.writefile(CONTENT, input_path)
		system({ 'xz', input_path })

		vim.cmd.edit()
	end)

	it('shows correct content', function()
		vim:assert_lines(CONTENT)
		assert.same('c', vim.bo.filetype)
		assert.True(vim.bo.modeline)
	end)

	it(':edit reloads content', function()
		vim.fn.writefile(OTHER_CONTENT, input_path)
		vim.fn.delete(xz_path)
		system({ 'xz', input_path })
		vim:assert_lines(CONTENT)
		vim.cmd.edit()
		vim:assert_lines(OTHER_CONTENT)
	end)

	it(':edit shows stderr when file does not exist', function()
		vim.fn.delete(xz_path)
		vim.cmd.edit()
		assert.matches('xz:.*No such file or directory', vim.fn.getline(1))
		assert.same('nofile', vim.bo.buftype)
		assert.same('', vim.bo.filetype)
		assert.False(vim.bo.modeline)
	end)

	it(':write checks read-only', function()
		vim.fn.setfperm(xz_path, '---------')
		assert.error_matches(vim.cmd.write, 'E505.*is read%-only')
		assert.False(vim.bo.modified)
	end)

	it(':write writes compressed file', function()
		vim.fn.setfperm(xz_path, '---------')
		vim:set_lines(OTHER_CONTENT)
		assert.True(vim.bo.modified)
		vim.cmd.write({ bang = true })
		assert.False(vim.bo.modified)
		assert.same(
			table.concat(OTHER_CONTENT, '\n') .. '\n',
			system({ 'xzcat', xz_path })
		)
		vim:assert_messages(string.format('"%s" written with xz', xz_path))
	end)
end)
