test('options unchanged when detection fails', function()
	vim.cmd([[
setlocal tabstop=42
Vimdent
	]])

	assert.same(vim.b.did_vimdent, nil)
	assert.same(vim.bo.tabstop, 42)
end)

test('buffer with single-space indentation ignored', function()
	vim.cmd([[
append
a
 b
  c
.
Vimdent
	]])

	assert.same(vim.b.did_vimdent, nil)
	assert.same(vim.bo.tabstop, 8)
	assert.same(vim.bo.expandtab, false)
	assert.same(vim.bo.shiftwidth, 8)
end)

test('buffer with double-space indentation correctly detected', function()
	vim.cmd([[
append
a
  b
    c
.
Vimdent
	]])

	assert.same(vim.b.did_vimdent, 1)
	assert.same(vim.bo.tabstop, 8)
	assert.same(vim.bo.expandtab, true)
	assert.same(vim.bo.shiftwidth, 2)
end)

test('buffer with tabs correctly detected', function()
	vim.cmd([[
append
a
	b
		c
.
Vimdent
	]])

	assert.same(vim.b.did_vimdent, 1)
	assert.same(vim.bo.tabstop, 8)
	assert.same(vim.bo.expandtab, false)
	assert.same(vim.bo.shiftwidth, 0)
end)

test(
	'buffer with mixed space and tab indentation correctly detected',
	function()
		vim.cmd([[
append
a
  b
	c
.
Vimdent
	]])

		assert.same(vim.b.did_vimdent, 1)
		assert.same(vim.bo.tabstop, 4)
		assert.same(vim.bo.expandtab, false)
		assert.same(vim.bo.shiftwidth, 2)
	end
)

test('options re-detected on &filetype set', function()
	vim.cmd([[
new test
append
a
  b
    c
.
	]])

	vim.cmd('setlocal filetype=c')
	assert.same(vim.b.did_vimdent, 1)

	-- Once only.
	vim.b.did_vimdent = nil
	vim.cmd('setlocal filetype=c')
	assert.same(vim.b.did_vimdent, nil)
end)

test('options re-detected on :write', function()
	vim.cmd([[
new test
append
a
  b
    c
.
	]])

	vim.cmd('doautocmd BufWritePost')
	assert.same(vim.b.did_vimdent, 1)

	-- Once only.
	vim.b.did_vimdent = nil
	vim.cmd('doautocmd BufWritePost')
	assert.same(vim.b.did_vimdent, nil)
end)

test('options detected only in file-backed buffers', function()
	vim.cmd([[
setlocal buftype=quickfix
append
a
  b
    c
.
Vimdent
	]])

	assert.same(vim.b.did_vimdent, nil)
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

	assert.same(vim.bo.tabstop, 8)

	vim.cmd('setlocal filetype=c')

	assert.same(vim.bo.tabstop, 42)
end)
