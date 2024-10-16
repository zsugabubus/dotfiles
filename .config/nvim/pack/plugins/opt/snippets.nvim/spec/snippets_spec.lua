local vim = create_vim({
	isolate = false,
	on_setup = function(vim)
		vim:lua(function()
			_G.vim.g.snippets = {
				get_snippets = function()
					return {
						{
							key = 'Z',
							callback = function()
								error('unreachable')
							end,
						},
						{
							key = 'S',
							callback = function()
								return nil
							end,
						},
						{
							key = 'S',
							callback = function()
								return _G.callback()
							end,
						},
					}
				end,
			}
			_G.vim.keymap.set({ 'i', 's' }, 'J', function()
				return require('snippets').jump() or '[done]'
			end, { expr = true, replace_keycodes = false })
			_G.vim.keymap.set('n', 'gh', 'i[remapped gh]<Esc>', {})
		end)
	end,
})

local function set_callback(x)
	vim:lua(function(x)
		if type(x) == 'table' then
			_G.callback = function()
				return x
			end
		else
			_G.callback = loadstring(x)
		end
	end, type(x) == 'function' and string.dump(x) or { body = x })
end

local function feed(...)
	return vim:feed(...)
end

local function macro_feed(s)
	vim.fn.setreg('q', _G.vim.keycode(s))
	vim.cmd.normal('@q')
end

local function set_lines(...)
	return vim:set_lines(...)
end

local function assert_lines(...)
	return vim:assert_lines(...)
end

local function assert_mode(mode)
	return assert.same(mode, vim.fn.mode())
end

it('allows inserting an empty snippet', function()
	set_callback('')
	macro_feed('ASJ')
	assert_lines({ '[done]' })
end)

it('allows inserting a text-only snippet', function()
	set_callback('test')
	macro_feed('ASJ')
	assert_lines({ 'test[done]' })
end)

it('allows editing a tabstop-only snippet', function()
	set_callback('$1$0')
	macro_feed('AStestJJ')
	assert_lines({ 'test[done]' })
end)

it('allows editing tabstop with default', function()
	set_callback('${1:default}$0')
	macro_feed('AStestJJ')
	assert_lines({ 'test[done]' })
end)

it('allows jumping over tabstop with default', function()
	set_callback('${1:default}$0')
	macro_feed('ASJJ')
	assert_lines({ 'default[done]' })
end)

it('allows overriding tabstop default via env function', function()
	set_callback(function()
		return {
			body = '${1:default}',
			env = {
				function()
					return 'env'
				end,
			},
		}
	end)
	macro_feed('ASJJ')
	assert_lines({ 'env[done]' })
end)

it('allows editing tabstop with env function', function()
	set_callback(function()
		return {
			body = '$1',
			env = {
				function()
					return 'env'
				end,
			},
		}
	end)
	macro_feed('AStestJJ')
	assert_lines({ 'test[done]' })
end)

it('allows overriding tabstop default via env string', function()
	set_callback(function()
		return {
			body = '${1:default}',
			env = { 'env' },
		}
	end)
	macro_feed('ASJJ')
	assert_lines({ 'env[done]' })
end)

it('allows editing tabstop with env string', function()
	set_callback(function()
		return {
			body = '$1',
			env = { 'env' },
		}
	end)
	macro_feed('AStestJJ')
	assert_lines({ 'test[done]' })
end)

it('evaluates env function of $0 once with an empty snippet', function()
	set_callback(function()
		local counter = 0
		return {
			body = '',
			env = {
				[0] = function()
					counter = counter + 1
					return 'test' .. counter
				end,
			},
		}
	end)
	macro_feed('ASJ')
	assert_lines({ 'test1[done]' })
end)

it('allows inserting tabstop mirrors', function()
	set_callback('$1 >$1< $2 >$2< >$2<')
	macro_feed('AStest1Jtest2JJ')
	assert_lines({ 'test1 >test1< test2 >test2< >test2<[done]' })
end)

it('allows inserting tabstop mirrors with default', function()
	set_callback('${1:test1} >$1< ${2:test2} >$2< >$2<')
	macro_feed('ASJJJ')
	assert_lines({ 'test1 >test1< test2 >test2< >test2<[done]' })
end)

it('allows inserting tabstop mirrors with env function', function()
	set_callback(function()
		return {
			body = '$1 >$1< $2 >$2<',
			env = {
				function()
					return 'env1'
				end,
				function()
					return 'env2'
				end,
			},
		}
	end)
	macro_feed('AStest1Jtest2JJ')
	assert_lines({ 'test1 >test1< test2 >test2<[done]' })
end)

it('selects $0 correctly with tabstop mirror right before it', function()
	set_callback('$1 $1$0')
	macro_feed('AStestJJ')
	assert_lines({ 'test test[done]' })
end)

it('allows env functions to access tabstop values', function()
	set_callback(function()
		return {
			body = '$3 $7 $4 $VAR',
			env = {
				[7] = function(x)
					return ('7(%s+%s)'):format(x[3], x[4])
				end,
				VAR = function(x)
					return x[7]
				end,
			},
		}
	end)
	macro_feed('AS3J4JJJ')
	assert_lines({ '3 7(3+4) 4 7(3+4)[done]' })
end)

it('handles live editing of tabstop mirrors', function()
	set_callback('$1 >$1< >$1<$2')
	feed('AStest')
	assert_lines({ 'test >test< >test<' })
	feed('0cetest1')
	assert_lines({ 'test1 >test1< >test1<' })
end)

it('handles live editing of dependent env functions', function()
	set_callback(function()
		return {
			body = '$1 $2 $3',
			env = {
				function()
					return '1'
				end,
				function(x)
					return '2' .. x[1] .. '2'
				end,
				function(x)
					return '3' .. x[2] .. '3'
				end,
			},
		}
	end)
	feed('AS')
	assert_lines({ '1 212 32123' })
	feed('101')
	assert_lines({ '101 21012 3210123' })
	feed('iJJJJ')
	assert_lines({ '101 21012 3210123[done]' })
end)

it('inserts nothing for an unknown variable', function()
	set_callback('>$VAR<')
	macro_feed('ASJ')
	assert_lines({ '><[done]' })
end)

it('inserts default of an unknown variable', function()
	set_callback('${VAR:default}')
	macro_feed('ASJ')
	assert_lines({ 'default[done]' })
end)

it('inserts defaults of nested unknown variables', function()
	set_callback('${A:a ${B:b ${C:c}}}')
	macro_feed('ASJ')
	assert_lines({ 'a b c[done]' })
end)

it('allows overriding variable default via env function', function()
	set_callback(function()
		return {
			body = '${VAR:default}',
			env = {
				VAR = function()
					return 'env'
				end,
			},
		}
	end)
	macro_feed('ASJ')
	assert_lines({ 'env[done]' })
end)

it('allows overriding variable default via env string', function()
	set_callback(function()
		return {
			body = '${VAR:default}',
			env = { VAR = 'env' },
		}
	end)
	macro_feed('ASJ')
	assert_lines({ 'env[done]' })
end)

it('inserts builtin variable; TM_SELECTED_TEXT', function()
	set_callback('$TM_SELECTED_TEXT')
	vim.fn.setreg('', '1\n2')
	macro_feed('ASJ')
	assert_lines({ '1', '2[done]' })
end)

it('inserts empty variable', function()
	set_callback('$TM_SELECTED_TEXT$1')
	vim.fn.setreg('', '')
	macro_feed('AStest1')
	-- TextChanged
	macro_feed('AJJ')
	assert_lines({ 'test1[done]' })
end)

it('visits tabstops in order', function()
	set_callback('$4 $1 $3 $2')
	macro_feed('AStest1Jtest2Jtest3Jtest4JJ')
	assert_lines({ 'test4 test1 test3 test2[done]' })
end)

it('handles non-consecutive tabstops', function()
	set_callback('$10 $99 $50')
	macro_feed('AStest10Jtest50Jtest99JJ')
	assert_lines({ 'test10 test99 test50[done]' })
end)

describe('tabstop selection', function()
	it('expand-insert', function()
		set_callback('>$1<')
		feed('AStestJ')
		assert_lines({ '>test<' })
		assert_mode('n')
	end)

	it('insert-insert', function()
		set_callback('>$1< >$2<')
		feed('AStest1Jtest2J')
		assert_lines({ '>test1< >test2<' })
		assert_mode('n')
	end)

	it('insert-select', function()
		set_callback('>$1< >${2:x}<')
		feed('AStest1J')
		assert_mode('s')
		feed('test2J')
		assert_lines({ '>test1< >test2<' })
		assert_mode('n')
	end)

	it('expand-select', function()
		set_callback('>${1:x}<')
		feed('AS')
		assert_mode('s')
		feed('testJ')
		assert_lines({ '>test<' })
		assert_mode('n')
	end)

	it('select-insert', function()
		set_callback('>${1:test1}< >$2<')
		feed('ASJtest2J')
		assert_lines({ '>test1< >test2<' })
		assert_mode('n')
	end)

	it('select-select', function()
		set_callback('>${1:test1}< >${2:x}<')
		feed('ASJ')
		assert_mode('s')
		feed('test2J')
		assert_lines({ '>test1< >test2<' })
		assert_mode('n')
	end)
end)

it('counts line indent in visual cells', function()
	set_callback('')
	set_lines({ ' \t \t' }) -- " \t" == "\t"
	macro_feed('ASJ')
	assert_lines({ '\t\t[done]' })
end)

it('counts line indent up to insertion column', function()
	set_callback('1\n2')
	set_lines({ ' \t' })
	macro_feed('aSJ')
	assert_lines({ ' 1', ' 2[done]\t' })
end)

it('counts snippet indent in shifted cells', function()
	vim.bo.shiftwidth = 3
	set_callback(' \t \t')
	macro_feed('ASJ')
	assert_lines({ '\t[done]' })
end)

it('indents all inserted lines', function()
	vim.bo.shiftwidth = 2
	set_callback('\n \t\n ')
	set_lines({ '\t ' })
	feed('ASJ')
	assert_lines({ '\t ', '\t    ', '\t  [done]' })
end)

it('indents tabstop default', function()
	vim.bo.shiftwidth = 2
	set_callback('${0:\t}')
	macro_feed('ASJ')
	assert_lines({ '  [done]' })
end)

it('respects vartabstop', function()
	vim.bo.shiftwidth = 3
	vim.bo.vartabstop = '2,4'
	set_callback('\t\n\t')
	set_lines({ '\t    ' }) -- "\t\t"
	macro_feed('ASJ')
	assert_lines({ '\t\t   ', '\t\t   [done]' })
end)

it('auto indents c', function()
	vim.bo.filetype = 'c'
	assert.same('', vim.bo.indentexpr)
	assert.False(vim.bo.expandtab)
	set_callback('')

	set_lines({ '{', '' })
	macro_feed('2GASJ')
	assert_lines({ '{', '\t[done]' })

	set_lines({ '\t{', '\t\t\t\t' })
	macro_feed('2GASJ')
	assert_lines({ '\t{', '\t\t[done]' })
end)

it('auto indents meson', function()
	vim.bo.filetype = 'meson'
	assert.not_same('', vim.bo.indentexpr)
	assert.True(vim.bo.expandtab)
	assert.same(2, vim.bo.shiftwidth)
	set_callback('if true\nendif')

	set_lines({ 'if true', '' })
	macro_feed('2GASJ')
	assert_lines({ 'if true', '  if true', '  endif[done]' })
	-- There is an `echom` in indent/meson.vim.
	vim:assert_messages('')
end)

it('auto indents python', function()
	vim.bo.filetype = 'python'
	assert.not_same('', vim.bo.indentexpr)
	assert.True(vim.bo.expandtab)
	assert.same(4, vim.bo.shiftwidth)
	set_callback('if True:\n\t')

	set_lines({ 'def x():', '    a = 1', '    ' })
	macro_feed('3GASJ')
	assert_lines({ 'def x():', '    a = 1', '    if True:', '        [done]' })
end)

it('preserves tabs outside indent', function()
	vim.bo.shiftwidth = 1
	set_callback('\tx\t')
	macro_feed('ASJ')
	assert_lines({ ' x\t[done]' })
end)

it(
	"doesn't change existing indent and preserves tabs when inserting after non-white",
	function()
		vim.bo.shiftwidth = 2
		set_callback('\t\n\t')
		set_lines({ ' \t \tx' })
		macro_feed('ASJ')
		assert_lines({ ' \t \tx\t', '\t\t  [done]' })
	end
)

it('uses the first auto jump candidate only', function()
	set_callback('$1 =: $2')
	macro_feed('AStest1:=test2JJ')
	assert_lines({ 'test1: =: test2[done]' })
end)

it('collects auto jump candidates from the next text run only', function()
	set_callback('$1 $2   =')
	macro_feed('AStest1=Jtest2=J')
	assert_lines({ 'test1= test2   =[done]' })
end)

describe('auto jumps when parenthesis are balanced;', function()
	local function test_case(open, close)
		local function f(s)
			return (s:gsub('[()]', { ['('] = open, [')'] = close }))
		end
		it(open .. close, function()
			set_callback(f('($1),$2'))
			macro_feed(f('ccS(test1))test2'))
			assert_lines({ f('((test1)),test2') })
		end)
	end

	test_case('(', ')')
	test_case('{', '}')
	test_case('[', ']')
end)

it('allows inserting nested snippets', function()
	set_callback('($1)')
	macro_feed('ASSStestJJJJ')
	assert_lines({ '(((test)))[done]' })
end)

it('provides up-to-date buffer to snippet callback', function()
	set_callback(function()
		return { body = _G.vim.fn.getline('.') }
	end)
	macro_feed('AtestSJ')
	assert_lines({ 'testtest[done]' })
end)

it('inserts snippet to the region returned by snippet callback', function()
	set_callback(function()
		return {
			body = '',
			start_row = 1,
			start_col = 2,
			end_row = 3,
			end_col = 4,
		}
	end)
	set_lines({
		'012345 0',
		'x>xxxx 1',
		'xxxxxx 2',
		'xxxx<x 3',
	})
	macro_feed('iSJ')
	assert_lines({
		'012345 0',
		'x>[done]<x 3',
	})
end)

it('allows snippet region with start_col only', function()
	set_callback(function()
		return { body = '', start_col = 1 }
	end)
	set_lines({ '01234' })
	macro_feed('3laSJ')
	assert_lines({ '0[done]4' })
end)

it('allows snippet region with end_col only', function()
	set_callback(function()
		return { body = '', end_col = 4 }
	end)
	set_lines({ '01234' })
	macro_feed('aSJ')
	assert_lines({ '0[done]4' })
end)

it("doesn't start new undo block", function()
	set_callback('world')
	macro_feed('Ahello SJ')
	assert_lines({ 'hello world[done]' })
	vim.cmd.undo()
	assert_lines({ '' })
end)

it('stops snippet when changing text outside placeholders', function()
	set_callback('$1 = $1')
	macro_feed('AS')
	macro_feed('i')
	macro_feed('ia')
	assert_lines({ 'a = a' })
	macro_feed('f=rx')
	-- TextChanged
	macro_feed('IJ')
	assert_lines({ '[done]a x a' })
end)

it('stops snippet when deleting a text run', function()
	set_callback('x$1\nx$2')
	macro_feed('AS<Esc>cc')
	-- TextChanged
	macro_feed('AJ')
	assert_lines({ '[done]', 'x' })
end)

it('stops snippet when deleting default text of a variable', function()
	set_callback('${VAR:default}$1\nx$2')
	macro_feed('AS<Esc>cc')
	-- TextChanged
	macro_feed('AJ')
	assert_lines({ '[done]', 'x' })
end)

it('stops snippet when deleting env default text of a variable', function()
	set_callback(function()
		return { body = '$VAR$1\nx$2', env = { VAR = 'x' } }
	end)
	macro_feed('AS<Esc>cc')
	-- TextChanged
	macro_feed('AJ')
	assert_lines({ '[done]', 'x' })
end)

it('stops snippet when deleting text of a known variable', function()
	set_callback('$TM_SELECTED_TEXT$1\nx$2')
	vim.fn.setreg('', 'x')
	macro_feed('AS<Esc>cc')
	-- TextChanged
	macro_feed('AJ')
	assert_lines({ '[done]', 'x' })
end)

it('stops snippet when jumping from outside of current tabstop', function()
	set_callback('$1,$2')
	macro_feed('AS<Esc>AJ')
	assert_lines({ ',[done]' })
end)

it('stops snippet when auto jumping from outside of current tabstop', function()
	set_callback('$1=$2')
	macro_feed('AS<Esc>A=J')
	assert_lines({ '==[done]' })
end)

it("doesn't stop snippet when deleting first line of multiline text", function()
	set_callback('$1x\n$2')
	macro_feed('AS<Esc>cc')
	-- TextChanged
	macro_feed('AJJJ')
	assert_lines({ '', '[done]' })
end)

it("doesn't stop snippet when deleting default text of a tabstop", function()
	set_callback(function()
		return {
			body = '${1:x $VAR_ENV ${VAR_DEFAULT:x} $TM_SELECTED_TEXT}',
			env = { VAR_ENV = 'x' },
		}
	end)
	vim.fn.setreg('', 'x')
	macro_feed('ASx<C-H>')
	-- TextChanged
	macro_feed('aJJ')
	assert_lines({ '[done]' })
end)

it(
	"doesn't stop snippet when deleting env default text of a tabstop",
	function()
		set_callback(function()
			return { body = '$1', env = { 'x' } }
		end)
		macro_feed('ASx<C-H>')
		-- TextChanged
		macro_feed('aJJ')
		assert_lines({ '[done]' })
	end
)

it("doesn't stop snippet when becomes empty", function()
	set_callback('${1:x}')
	macro_feed('AS<C-H>')
	-- TextChanged
	macro_feed('aJJ')
	assert_lines({ '[done]' })
end)

it("doesn't stop snippet when changing text in other buffers", function()
	set_callback('${1:current}')
	macro_feed('AS')
	vim.cmd.enew()
	feed('Aother')
	assert_lines({ 'other' })
	vim.cmd.buffer('#')
	macro_feed('AJJ')
	assert_lines({ 'current[done]' })
end)
