local vim = create_vim()

local function edit_with_content(s)
	local path = vim.fn.tempname()
	local f = assert(io.open(path, 'w'))
	assert(f:write(s))
	assert(f:close())
	vim.cmd.edit(vim.fn.fnameescape(path))
end

test(':Varign calculates vartabstop', function()
	vim:set_lines({
		'a\t\tbbbb',
		'a\t\tb\tc\t',
		'a\t\tb\tcc\t',
		'xxxxxxx',
	})
	vim.cmd.Varign()
	assert.same('2,1,5,3', vim.o.vartabstop)
	vim:set_lines({ 'a\t' })
	assert.same('2', vim.o.vartabstop)
end)

test('control characters', function()
	edit_with_content('\x00\x01\x02\t')
	vim.cmd.Varign()
	assert.same('7', vim.o.vartabstop)
end)

test('auto attach', function()
	local THREE_COLUMNS = 'a\tb\tc'

	local function assert_attached(s)
		edit_with_content(s)
		return assert.not_same('', vim.o.vartabstop)
	end

	local function assert_not_attached(s)
		edit_with_content(s)
		return assert.same('', vim.o.vartabstop)
	end

	assert_attached(THREE_COLUMNS)
	assert_attached(THREE_COLUMNS .. 'x')
	assert_attached(THREE_COLUMNS .. '\tfoo bar')

	assert_not_attached('\t' .. THREE_COLUMNS)
	assert_not_attached('\n' .. THREE_COLUMNS)
	assert_not_attached('\r' .. THREE_COLUMNS)
	assert_not_attached('a\t\t')
	assert_not_attached('a\t\tc')
	assert_not_attached('a\tb\t')

	for i = 0, string.byte(' ') - 1 do
		local s = string.char(i)
		if s ~= '\t' and s ~= '\n' and s ~= '\r' then
			assert_not_attached(THREE_COLUMNS .. s)
		end
	end
end)
