local vim = create_vim({
	on_setup = function(vim)
		vim.keymap.set('', 'gc', '<Plug>(commenter)')
		vim.keymap.set('', 'gcc', '<Plug>(commenter-current-line)')
	end,
})

describe('toggling comment', function()
	local function default_setup()
		vim.o.shiftwidth = 2
		vim.o.tabstop = 4
	end

	local function test_case(name, cms, input, output, setup)
		it(name, function()
			vim.o.cms = cms;
			(setup or default_setup)()
			vim:set_lines(type(input) == 'table' and input or { input })
			vim:feed('gcG')
			vim:assert_lines(type(output) == 'table' and output or { output })
		end)
	end

	-- stylua: ignore start
	test_case('leaves empty line intact', '#%s', '', '')
	test_case('leaves blank line intact', '#%s', ' \t ', ' \t ')
	test_case('does nothing when all lines are blank', '#%s', { '', ' \t' }, { '', ' \t' })
	test_case('uses a default commentstring when it is empty', '', 'x', '# x')
	test_case('adds one space of padding', '/*%s*/', 'x ', '/* x  */')
	test_case('removes one space of padding', '/*%s*/', '/*  x  */', ' x ')
	test_case('ignores space padding in commentstring when commenting', '/*  %s  */', 'x', '/* x */')
	test_case('ignores space padding in commentstring when uncommenting', '/*  %s  */', '/*x*/', 'x')
	test_case('preserves trailing space when commentstring has left part only', '#%s', '# x  ', 'x  ')
	test_case('ignores comments at the middle of the line', '#%s', 'x # x', '# x # x')
	test_case('uncomments first inline comment only', '/*%s*/', '/*1*//*2*/', '1/*2*/')
	test_case('treats broken inline comment as uncommented', '/*%s*/', '/*', '/* /* */')
	test_case('removes sticky asterisks', '/*%s*/', '/*** * ***/', '*')
	test_case('removes sticky slashes', '//%s', '//// /', '/')
	test_case('removes sticky dashes', '--%s', '---- -', '-')
	test_case('does case-sensitive commentstring matching', 'REM %s', 'rem', 'REM rem')
	test_case('handles special pattern characters in commentstring', '[*]%s[*]', '[*]x[*]', 'x')
	test_case('empties blank line when uncommenting inline comment', '/*%s*/', ' \t /***/', '')
	test_case('empties blank line when uncommenting line comment', '//%s', ' \t ////', '')
	test_case('does not comment leading blank lines', '#%s', { '', ' \t ', 'x' }, { '', ' \t ', '# x' })
	test_case('reindents when commenting', '#%s', '    x', '\t# x')
	test_case('uses the same indent for all commented lines', '#%s', { '  x', '\tx' }, { '  # x', '  #   x' })
	test_case('expands commented tabs when &sw!=&ts', '#%s', { 'x', '\tx' }, { '# x', '#     x' })
	test_case('expands commented tabs with &vts', '#%s', { '\tx', '\t\t\tx' }, { '\t# x', '\t#    x' }, function()
		vim.o.vartabstop = '10,1,2'
	end)
	test_case('expands commented tabs when indent not on tabstop', '#%s', { ' x', '\t\tx' }, { ' # x', ' #    x' }, function()
		vim.o.shiftwidth = 2
		vim.o.tabstop = 2
	end)
	test_case('does not expand commented tabs when &sw=&ts', '#%s', { 'x', '\tx' }, { '# x', '# \tx' }, function()
		vim.o.shiftwidth = 2
		vim.o.tabstop = 2
	end)
	test_case('does not expand commented tabs when &sw=0', '#%s', { 'x', '\tx' }, { '# x', '# \tx' }, function()
		vim.o.shiftwidth = 0
		vim.o.tabstop = 2
	end)
	test_case('reindents blank lines', '#%s', { '\tx', ' ' }, { '\t# x', '\t#' })
	test_case('reindents when uncommenting', '#%s', '  #   x', '\tx')
	test_case('comments each line when first non-blank is uncommented', '#%s', { '', ' \t', 'x', '#x' }, { '', ' \t', '# x', '# #x' })
	test_case('uncomments each line when first non-blank is commented', '#%s', { '', ' \t', '#x', 'x' }, { '', ' \t', 'x', 'x' })
	-- stylua: ignore end
end)

local function assert_toggles(keys, uncommented, commented)
	vim:set_lines(uncommented)
	vim:feed(keys)
	vim:assert_lines(commented)
	vim:feed('gg' .. keys)
	vim:set_lines(uncommented)
end

describe('<Plug>(commenter)', function()
	it('toggles comment over motion', function()
		assert_toggles(
			'2gc2j',
			{ '1', '2', '3', '4', '5', '6' },
			{ '# 1', '# 2', '# 3', '# 4', '# 5', '6' }
		)
	end)
end)

describe('<Plug>(commenter-current-line)', function()
	it('toggles comment on the current line by default', function()
		assert_toggles('gcc', { '1', '2' }, { '# 1', '2' })
	end)

	it('toggles comment on [count] lines', function()
		assert_toggles('1gcc', { '1', '2', '3' }, { '# 1', '2', '3' })
		assert_toggles('2gcc', { '1', '2', '3' }, { '# 1', '# 2', '3' })
	end)
end)

it('dot repeat', function()
	local function test_case(keys)
		vim.o.cms = '*%s'
		vim:set_lines({ '1', '2', '* 3', '4' })
		vim:feed('gg' .. keys)
		vim:assert_lines({ '* 1', '* 2', '* 3', '4' })
		vim:feed('j.')
		vim:assert_lines({ '* 1', '2', '3', '4' })
	end

	test_case('gcj')
	test_case('2gcc')
	test_case('Vjgc')
end)

describe(':Comment', function()
	it('comments current line without range', function()
		vim:set_lines({ '1', '2' })
		vim.cmd('Comment')
		vim:assert_lines({ '# 1', '2' })
	end)

	it('comments range', function()
		vim:set_lines({ '1', '2', '3', '4' })
		vim.cmd('2,3Comment')
		vim:assert_lines({ '1', '# 2', '# 3', '4' })
	end)

	it('does not uncomment lines', function()
		vim:set_lines({ '# 1' })
		vim.cmd('Comment')
		vim:assert_lines({ '# # 1' })
	end)

	it('allows commenting empty lines', function()
		vim:set_lines({ '', ' \t ' })
		vim.cmd('%Comment')
		vim:assert_lines({ '#', '#' })
	end)
end)

describe(':Uncomment', function()
	it('uncomments current line without range', function()
		vim:set_lines({ '# 1', '# 2' })
		vim.cmd('Uncomment')
		vim:assert_lines({ '1', '# 2' })
	end)

	it('uncomments range', function()
		vim:set_lines({ '# 1', '# 2', '# 3', '# 4' })
		vim.cmd('2,3Uncomment')
		vim:assert_lines({ '# 1', '2', '3', '# 4' })
	end)

	it('does not comment lines', function()
		vim:set_lines({ '1' })
		vim.cmd('Uncomment')
		vim:assert_lines({ '1' })
	end)
end)

it('reports number of changed lines', function()
	local function test_case(report, keys, message)
		vim.cmd.echo()
		vim:set_lines({ '1', '2', '' })
		vim.o.report = report
		vim:feed('gg' .. keys)
		local screen = vim:get_screen()
		local cmdline = screen[#screen]
		return assert.same(message, cmdline)
	end

	test_case(0, '3Ggcc', '--No lines to comment--')
	test_case(0, 'gcc', '1 line commented')
	test_case(0, '1gcc', '1 line commented')
	test_case(0, 'gccgcc', '1 line uncommented')
	test_case(0, 'gcj', '2 lines commented')
	test_case(0, 'gcjgcj', '2 lines uncommented')
	test_case(1, 'gcc', '')
	test_case(1, 'gcj', '2 lines commented')
	test_case(1, '2gcc', '2 lines commented')
	test_case(1, 'gcjgcj', '2 lines uncommented')
	test_case(2, 'gcj', '')
	test_case(2, '3gcc', '3 lines commented')
	test_case(9, '3Ggcc', '--No lines to comment--')
end)

describe('uses treesitter to find commentstring', function()
	it('lua', function()
		vim.o.filetype = 'lua'
		vim.o.cms = '---%s'
		vim:set_lines({
			'vim.api.nvim_exec2([[',
			'let x',
			'lua <<EOF',
			'local x',
			'EOF',
			'let x',
			']])',
		})
		vim:feed('6Ggcc')
		vim:feed('4Ggcc')
		vim:feed('2Ggcc')
		vim:feed('1Ggcc')
		vim:assert_lines({
			'--- vim.api.nvim_exec2([[',
			'" let x',
			'lua <<EOF',
			'--- local x',
			'EOF',
			'" let x',
			']])',
		})
	end)

	it('markdown', function()
		vim.o.filetype = 'markdown'
		vim:set_lines({
			'x',
			'# x',
			'```c',
			'int x;',
			'```',
		})
		vim:feed('1Ggcc')
		vim:feed('2Ggcc')
		vim:feed('4Ggcc')
		vim:assert_lines({
			'<!-- x -->',
			'<!-- # x -->',
			'```c',
			'/* int x; */',
			'```',
		})
	end)
end)

describe('get_commentstring', function()
	it('can be overridden', function()
		vim:lua(function()
			_G.vim.g.commenter = {
				get_commentstring = function(buf, row)
					assert(buf == 0)
					return row .. '%s'
				end,
			}
		end)
		vim:set_lines({ 'a', 'b', 'c' })
		vim:feed('gcj')
		vim:feed('3Ggcc')
		vim:assert_lines({ '0 a', '0 b', '2 c' })
	end)
end)
