local vim = create_vim({
	on_setup = function(vim)
		vim:lua(function()
			require('varign').setup()
		end)
	end,
})

test(':Varign', function()
	vim:set_lines({ '\t' })
	vim.cmd.Varign()
	assert.same(vim.o.vartabstop, '1')

	vim:set_lines({ 'a\t' })
	assert.same(vim.o.vartabstop, '2')
end)

test('BufReadPost', function()
	local function fails(lines)
		vim:set_lines(lines)
		vim.cmd.doautocmd('BufReadPost')
		return assert.same(vim.o.vartabstop, '')
	end

	fails({ '\ta\tb\tc' })
	fails({ 'a\t\t' })
	fails({ 'a\t\tc' })
	fails({ 'a\tb\t' })
	fails({ '', 'a\tb\tc' })

	vim:set_lines({ 'a\tb\tc' })
	vim.cmd.doautocmd('BufReadPost')
	assert.same(vim.o.vartabstop, '2,2')

	vim:set_lines({ 'a\t' })
	assert.same(vim.o.vartabstop, '2')
end)

test('vartabstop', function()
	vim:set_lines({
		'a\t\tbbbb',
		'a\t\tb\tc\t',
		'a\t\tb\tcc\t',
		'xxxxxxx',
	})
	vim.cmd.Varign()
	assert.same(vim.o.vartabstop, '2,1,5,3')
end)
