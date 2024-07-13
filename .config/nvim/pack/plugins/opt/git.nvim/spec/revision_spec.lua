local vim = create_vim({ isolate = false })

local M = setmetatable({}, {
	__index = function(_, k)
		return function(...)
			return unpack(vim:lua(function(k, ...)
				return { require('git.revision')[k](...) }
			end, k, ...))
		end
	end,
})

test('canonical()', function()
	local function test_case(input, output)
		return assert.same(output, M.canonical(input))
	end

	test_case('~', '~')
	test_case('^', '~')
	test_case('~0', '')
	test_case('~~', '~2')
	test_case('~1~1', '~2')
	test_case('~~0~', '~2')
	test_case('~^~', '~3')
	test_case('~^1~', '~3')
	test_case('~^2~', '~^2~')
	test_case('~10', '~10')
	test_case('^10', '^10')
end)

test('parent_tree()', function()
	local function test_case(input, output)
		return assert.same(output, M.parent_tree(input))
	end

	test_case('@:', '@:')
	test_case('@:a', '@:')
	test_case('@:a/', '@:')
	test_case('@:a/b', '@:a/')
	test_case('@:a/b/c', '@:a/b/')
	test_case(':1:a/b', ':1:a/')
	test_case(':1:a/', ':1:')
	test_case(':1:', ':1:')
end)

test('split_path()', function()
	local function test_case(input, rev, path)
		return assert.same({ rev, path }, { M.split_path(input) })
	end

	test_case('@', '@', '')
	test_case('@:', '@', '')
	test_case('@:a', '@', 'a')
	test_case(':1', ':1', '')
	test_case(':1:', ':1', '')
	test_case(':1:a', ':1', 'a')
	test_case('master~1^2:a/b', 'master~1^2', 'a/b')
end)

test('join()', function()
	local function test_case(left, right, output)
		return assert.same(output, M.join(left, right))
	end

	test_case('@:a', 'b', '@:a/b')
	test_case('@', 'aaa', '@:aaa')
	test_case('@', '09aF', '09aF')
	test_case('@', 'aaaaX', '@:aaaaX')
	test_case('@', 'Xaaaa', '@:Xaaaa')
	test_case('@', 'refs/', 'refs/')
	test_case('@', 'Xrefs/', '@:Xrefs/')
end)

test('parent_commit()', function()
	local function test_case(base, n, output)
		return assert.same(output, M.parent_commit(base, n))
	end

	test_case('@', 1, '@~')
	test_case('@', 2, '@^2')
	test_case('@:a', 2, '@^2:a')
	test_case('@~', 1, '@~2')
end)

test('ancestor()', function()
	local function test_case(base, n, output)
		return assert.same(output, M.ancestor(base, n))
	end

	test_case('@', 1, '@~')
	test_case('@', 2, '@~2')
	test_case('@:a', 1, '@~:a')
	test_case('@:a', 2, '@~2:a')
	test_case('@~', 1, '@~2')
end)
