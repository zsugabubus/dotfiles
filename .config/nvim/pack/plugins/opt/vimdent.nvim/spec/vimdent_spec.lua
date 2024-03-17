local vim = create_vim({ isolate = false, height = 20 })

test('options unchanged when detection fails', function()
	vim.cmd('setlocal tabstop=42')
	vim.cmd.Vimdent()

	assert.same(nil, vim.b.did_vimdent)
	assert.same(42, vim.bo.tabstop)
end)

test('buffer with single-space indentation ignored', function()
	vim:set_lines({ 'a', ' b', '  c' })
	vim.cmd.Vimdent()

	assert.same(nil, vim.b.did_vimdent)
	assert.same(8, vim.bo.tabstop)
	assert.same(false, vim.bo.expandtab)
	assert.same(8, vim.bo.shiftwidth)
end)

test('buffer with double-space indentation correctly detected', function()
	vim:set_lines({ 'a', '  b', '    c' })
	vim.cmd.Vimdent()

	assert.same(1, vim.b.did_vimdent)
	assert.same(8, vim.bo.tabstop)
	assert.same(true, vim.bo.expandtab)
	assert.same(2, vim.bo.shiftwidth)
end)

test('buffer with tabs correctly detected', function()
	vim:set_lines({ 'a', '\tb', '\t\tc' })
	vim.cmd.Vimdent()

	assert.same(1, vim.b.did_vimdent)
	assert.same(8, vim.bo.tabstop)
	assert.same(false, vim.bo.expandtab)
	assert.same(0, vim.bo.shiftwidth)
end)

test(
	'buffer with mixed space and tab indentation correctly detected',
	function()
		vim:set_lines({ 'a', '  b', '\tc' })
		vim.cmd.Vimdent()

		assert.same(1, vim.b.did_vimdent)
		assert.same(4, vim.bo.tabstop)
		assert.same(false, vim.bo.expandtab)
		assert.same(2, vim.bo.shiftwidth)
	end
)

test('options re-detected on &filetype set', function()
	vim.cmd.new('test')
	vim:set_lines({ 'a', '  b', '    c' })

	vim.cmd('setlocal filetype=c')
	assert.same(1, vim.b.did_vimdent)

	-- Once only.
	vim.b.did_vimdent = nil
	vim.cmd('setlocal filetype=c')
	assert.same(nil, vim.b.did_vimdent)
end)

test('options re-detected on :write', function()
	vim.cmd.new('test')
	vim:set_lines({ 'a', '  b', '    c' })

	vim.cmd('doautocmd BufWritePost')
	assert.same(1, vim.b.did_vimdent)

	-- Once only.
	vim.b.did_vimdent = nil
	vim.cmd('doautocmd BufWritePost')
	assert.same(nil, vim.b.did_vimdent)
end)

test('options detected only in file-backed buffers', function()
	vim.bo.buftype = 'quickfix'
	vim:set_lines({ 'a', '  b', '    c' })
	vim.cmd.Vimdent()

	assert.same(nil, vim.b.did_vimdent)
end)

test('&filetype fallback copies options from detected buffer', function()
	vim.cmd([[
new ok_but_not_c
setlocal filetype=not_c tabstop=99
let b:did_vimdent = 1

new not_ok
setlocal filetype=c tabstop=99

new first
setlocal filetype=c tabstop=42
let b:did_vimdent = 1

new second_ignored
setlocal filetype=c tabstop=99
let b:did_vimdent = 1

new test
	]])

	assert.same(8, vim.bo.tabstop)

	vim.cmd('setlocal filetype=c')

	assert.same(42, vim.bo.tabstop)
end)
