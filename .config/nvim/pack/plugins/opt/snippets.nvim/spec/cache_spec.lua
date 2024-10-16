local vim = create_vim({ isolate = false })

describe('make_filetype_cache()', function()
	before_each(function()
		vim:lua(function()
			local counter = 0
			_G.callback = require('snippets.cache').make_filetype_cache(
				function(filetype)
					counter = counter + 1
					return { counter, filetype }
				end
			)
		end)
	end)

	local function callback(...)
		return vim:lua(function(...)
			return _G.callback(...)
		end, ...)
	end

	local function buf(ft)
		vim.cmd.new()
		vim.bo.filetype = ft
		return vim.fn.bufnr()
	end

	local function buf2(a_ft, b_ft)
		local a, b = buf(a_ft), buf(b_ft)
		assert.not_same(a, b)
		return a, b
	end

	it('single buffer, different rows', function()
		local a = buf()
		assert.same({ 1, '' }, callback(a, 0))
		assert.same({ 1, '' }, callback(a, 1))
	end)

	it('multiple buffers, same filetype', function()
		local a, b = buf2()
		assert.same({ 1, '' }, callback(a, 0))
		assert.same({ 1, '' }, callback(b, 0))
	end)

	it('multiple buffers, different filetype', function()
		local a, b = buf2('a', 'b')
		assert.same({ 1, 'a' }, callback(a, 0))
		assert.same({ 2, 'b' }, callback(b, 0))
		assert.same({ 1, 'a' }, callback(a, 0))
		assert.same({ 2, 'b' }, callback(b, 0))
	end)

	it('FileType', function()
		local a, b = buf2()
		assert.same({ 1, '' }, callback(a, 0))
		assert.same({ 1, '' }, callback(b, 0))
		vim:vim('set filetype=c')
		assert.same({ 1, '' }, callback(a, 0))
		assert.same({ 2, 'c' }, callback(b, 0))
	end)

	it('language filetypes', function()
		vim:lua(function()
			_G.vim.treesitter.language.register('c', 'c2')
			_G.vim.treesitter.language.register('c', 'c3')
		end)
		local a, b = buf2('c', 'c')
		assert.same({ 1, 'c', 2, 'c2', 3, 'c3' }, callback(a, 0))
		assert.same({ 1, 'c', 2, 'c2', 3, 'c3' }, callback(b, 0))
	end)

	it('language injections', function()
		local a = buf('vim')
		vim:set_lines({
			'lua <<EOF',
			'EOF',
			'" vim',
		})
		assert.same({ 1, 'vim' }, callback(a, 0))
		assert.same({ 2, 'lua' }, callback(a, 1))
		assert.same({ 1, 'vim' }, callback(a, 2))
	end)
end)
