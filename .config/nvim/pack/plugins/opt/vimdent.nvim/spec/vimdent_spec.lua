local vim = create_vim({ isolate = false, height = 20 })

local DOUBLE_SPACE = { 'a', '  b', '    c' }

it('does not change options when detection fails', function()
	vim.cmd('setlocal tabstop=42')
	vim.cmd.Vimdent()

	assert.same(nil, vim.b.did_vimdent)
	assert.same(42, vim.bo.tabstop)
end)

it('ignores single-space indentation', function()
	vim:set_lines({ 'a', ' b', '  c' })
	vim.cmd.Vimdent()

	assert.same(nil, vim.b.did_vimdent)
	assert.same(8, vim.bo.tabstop)
	assert.same(false, vim.bo.expandtab)
	assert.same(8, vim.bo.shiftwidth)
end)

it('detects double-space indentation', function()
	vim:set_lines(DOUBLE_SPACE)
	vim.cmd.Vimdent()

	assert.same(1, vim.b.did_vimdent)
	assert.same(8, vim.bo.tabstop)
	assert.same(true, vim.bo.expandtab)
	assert.same(2, vim.bo.shiftwidth)
end)

it('detects tab-only indentation', function()
	vim:set_lines({ 'a', '\tb', '\t\tc' })
	vim.cmd.Vimdent()

	assert.same(1, vim.b.did_vimdent)
	assert.same(8, vim.bo.tabstop)
	assert.same(false, vim.bo.expandtab)
	assert.same(0, vim.bo.shiftwidth)
end)

it('detects mixed space and tab indentation', function()
	vim:set_lines({ 'a', '  b', '\tc' })
	vim.cmd.Vimdent()

	assert.same(1, vim.b.did_vimdent)
	assert.same(4, vim.bo.tabstop)
	assert.same(false, vim.bo.expandtab)
	assert.same(2, vim.bo.shiftwidth)
end)

it('ignores non-file buffers', function()
	vim:set_lines(DOUBLE_SPACE)

	vim.bo.buftype = 'quickfix'
	vim.cmd.Vimdent()

	assert.same(nil, vim.b.did_vimdent)

	vim.bo.buftype = ''
	vim.cmd.Vimdent()

	assert.same(1, vim.b.did_vimdent)
end)

it('detects indentation on BufNewFile', function()
	vim:set_lines(DOUBLE_SPACE)

	vim.cmd('doautocmd BufNewFile')
	assert.same(1, vim.b.did_vimdent)
end)

it('detects indentation on BufReadPost', function()
	vim:set_lines(DOUBLE_SPACE)

	vim.cmd('doautocmd BufReadPost')
	assert.same(nil, vim.b.did_vimdent)
	vim.cmd('doautocmd BufEnter')
	assert.same(1, vim.b.did_vimdent)

	-- Once only.
	vim.b.did_vimdent = nil
	vim.cmd('doautocmd BufEnter')
	assert.same(nil, vim.b.did_vimdent)
end)

it('detects indentation on FileType', function()
	vim.cmd.new('new')
	vim:set_lines(DOUBLE_SPACE)

	assert.same(nil, vim.b.did_vimdent)
	vim.cmd('setlocal filetype=c')
	assert.same(1, vim.b.did_vimdent)

	-- Once only.
	vim.b.did_vimdent = nil
	vim.cmd('setlocal filetype=c')
	assert.same(nil, vim.b.did_vimdent)
end)

it('detects indentation on BufWritePost', function()
	vim.cmd.new('new')
	vim:set_lines(DOUBLE_SPACE)

	assert.same(nil, vim.b.did_vimdent)
	vim.cmd('doautocmd BufWritePost')
	assert.same(1, vim.b.did_vimdent)

	-- Once only.
	vim.b.did_vimdent = nil
	vim.cmd('doautocmd BufWritePost')
	assert.same(nil, vim.b.did_vimdent)
end)

it('copies options from other buffer based on filetype', function()
	vim.cmd([[
new ok_but_not_c
setlocal filetype=not_c tabstop=99
let b:did_vimdent = 1

new not_ok
setlocal filetype=c tabstop=99

new first
setlocal filetype=c tabstop=16
let b:did_vimdent = 1

new second_ignored
setlocal filetype=c tabstop=99
let b:did_vimdent = 1
	]])

	vim.cmd.new('test')
	assert.same(8, vim.bo.tabstop)
	assert.same(nil, vim.b.did_vimdent)

	vim.cmd('setlocal filetype=c')
	assert.same(16, vim.bo.tabstop)
	assert.same(nil, vim.b.did_vimdent)

	vim.cmd.new('test.c')
	assert.same(16, vim.bo.tabstop)
	assert.same(nil, vim.b.did_vimdent)
end)
