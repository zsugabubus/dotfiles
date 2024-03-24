local vim = create_vim({ isolate = false })

local M = setmetatable({}, {
	__index = function(t, k)
		return function(...)
			return unpack(vim:lua(function(k, ...)
				return { require('git.revision')[k](...) }
			end, k, ...))
		end
	end,
})

test('canonical', function()
	assert.same('~', M.canonical('~'))
	assert.same('~', M.canonical('^'))
	assert.same('', M.canonical('~0'))
	assert.same('~2', M.canonical('~~'))
	assert.same('~2', M.canonical('~1~1'))
	assert.same('~2', M.canonical('~~0~'))
	assert.same('~3', M.canonical('~^~'))
	assert.same('~3', M.canonical('~^1~'))
	assert.same('~^2~', M.canonical('~^2~'))
	assert.same('~10', M.canonical('~10'))
	assert.same('^10', M.canonical('^10'))
end)

test('parent_tree', function()
	assert.same('@:', M.parent_tree('@:'))
	assert.same('@:', M.parent_tree('@:a'))
	assert.same('@:', M.parent_tree('@:a/'))
	assert.same('@:a/', M.parent_tree('@:a/b'))
	assert.same('@:a/b/', M.parent_tree('@:a/b/c'))
	assert.same(':1:a/', M.parent_tree(':1:a/b'))
end)

test('split_path', function()
	assert.same({ '@', '' }, { M.split_path('@') })
	assert.same({ '@', '' }, { M.split_path('@:') })
	assert.same({ '@', 'a' }, { M.split_path('@:a') })
	assert.same({ ':1', '' }, { M.split_path(':1') })
	assert.same({ ':1', '' }, { M.split_path(':1:') })
	assert.same({ ':1', 'a' }, { M.split_path(':1:a') })
end)

test('join', function()
	assert.same('@:a/b', M.join('@:a', 'b'))
	assert.same('@:aaa', M.join('@', 'aaa'))
	assert.same('09aF', M.join('@', '09aF'))
	assert.same('@:aaaaX', M.join('@', 'aaaaX'))
	assert.same('@:Xaaaa', M.join('@', 'Xaaaa'))
	assert.same('refs/', M.join('@', 'refs/'))
	assert.same('@:Xrefs/', M.join('@', 'Xrefs/'))
end)

test('parent_commit', function()
	assert.same('@~', M.parent_commit('@', 1))
	assert.same('@^2', M.parent_commit('@', 2))
	assert.same('@^2:a', M.parent_commit('@:a', 2))
	assert.same('@~2', M.parent_commit('@~', 1))
end)

test('ancestor', function()
	assert.same('@~', M.ancestor('@', 1))
	assert.same('@~2', M.ancestor('@', 2))
	assert.same('@~2:a', M.ancestor('@:a', 2))
	assert.same('@~2', M.ancestor('@~', 1))
	assert.same('@~:a', M.ancestor('@:a', 1))
end)
