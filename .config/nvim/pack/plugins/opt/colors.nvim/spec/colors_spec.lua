local vim = create_vim()

local RED = { bg = 0xff0000, fg = 0xffffff }
local GREEN = { bg = 0x00ff00, fg = 0x000000 }
local BLUE = { bg = 0x0000ff, fg = 0xffffff }

local function setup(config)
	vim:lua(function(config)
		_G.vim.g.colors = config
		require('colors').load_library()
	end, config)
end

it('correctly highlights after ColorScheme', function()
	setup()
	vim:set_lines({ 'red 0x0f0', 'x rgb(0,0,255) x' })
	local hls = {
		{ hl = RED, region = { 0, 0, 0, 3 } },
		{ hl = GREEN, region = { 0, 4, 0, 9 } },
		{ hl = BLUE, region = { 1, 2, 1, 14 } },
	}
	vim:assert_highlights(hls)
	vim.cmd.colorscheme('default')
	vim:assert_highlights(hls)
end)

it('correctly highlights after :redo', function()
	setup()
	vim:set_lines({ 'x red x' })
	local hls = {
		{ hl = RED, region = { 0, 2, 0, 5 } },
	}
	vim:assert_highlights(hls)
	vim.cmd.undo()
	vim:assert_highlights({})
	vim.cmd.redo()
	vim:assert_highlights(hls)
end)

it('can attach then detach from buffer', function()
	local function is_attached_to_buffer()
		return require('colors').is_attached_to_buffer(
			_G.vim.api.nvim_get_current_buf()
		)
	end

	setup({ auto_attach = false })

	vim:set_lines({ 'red' })
	assert.False(vim:lua(is_attached_to_buffer))
	vim:assert_highlights({})

	vim:lua(function()
		require('colors').attach_to_buffer(_G.vim.api.nvim_get_current_buf())
	end)
	assert.True(vim:lua(is_attached_to_buffer))
	vim:assert_highlights({
		{ hl = RED, region = { 0, 0, 0, 3 } },
	})

	vim:set_lines({ '0x0f0' })
	vim:assert_highlights({
		{ hl = GREEN, region = { 0, 0, 0, 5 } },
	})

	vim:lua(function()
		require('colors').detach_from_buffer(_G.vim.api.nvim_get_current_buf())
	end)
	assert.False(vim:lua(is_attached_to_buffer))
	vim:assert_highlights({})

	vim:set_lines({ 'red' })
	vim:assert_highlights({})
end)

describe('max_highlights_per_line', function()
	it('limits highlights per line', function()
		setup({ max_highlights_per_line = 1 })
		vim:set_lines({
			'red red',
			'red red',
		})
		vim:assert_highlights({
			{ hl = RED, region = { 0, 0, 0, 3 } },
			{ hl = RED, region = { 1, 0, 1, 3 } },
		})
	end)
end)

describe('max_lines_to_highlight', function()
	before_each(function()
		setup({ max_lines_to_highlight = 1 })
	end)

	it('limits initial number of lines to highlight', function()
		local path = vim.fn.tempname()
		vim.fn.writefile({
			'red red',
			'red red',
		}, path)
		vim.cmd.edit(vim.fn.fnameescape(path))
		vim:assert_highlights({
			{ hl = RED, region = { 0, 0, 0, 3 } },
			{ hl = RED, region = { 0, 4, 0, 7 } },
		})
	end)

	it('allows highlighting changed lines outside limit', function()
		vim:set_lines({
			'red red',
			'red red',
		})
		vim:assert_highlights({
			{ hl = RED, region = { 0, 0, 0, 3 } },
			{ hl = RED, region = { 0, 4, 0, 7 } },
			{ hl = RED, region = { 1, 0, 1, 3 } },
			{ hl = RED, region = { 1, 4, 1, 7 } },
		})
	end)
end)

describe('auto_attach', function()
	local function setup_auto_attach(value)
		setup({ auto_attach = value })
	end

	local function setup_auto_attach_fn(return_value)
		vim:lua(function(return_value)
			_G.calls = {}
			_G.vim.g.colors = {
				auto_attach = function(...)
					table.insert(_G.calls, { ... })
					return return_value
				end,
			}
			require('colors').load_library()
		end, return_value)
	end

	local function get_calls()
		return vim:lua(function()
			return _G.calls
		end)
	end

	it('default', function()
		setup()
		vim:set_lines({ 'red' })
		vim:assert_highlights({
			{ hl = RED, region = { 0, 0, 0, 3 } },
		})
	end)

	it('false', function()
		setup_auto_attach(false)
		vim:set_lines({ 'red' })
		vim:assert_highlights({})
	end)

	it('true', function()
		setup_auto_attach(true)
		vim:set_lines({ 'red' })
		vim:assert_highlights({
			{ hl = RED, region = { 0, 0, 0, 3 } },
		})
	end)

	it('function returns false', function()
		setup_auto_attach_fn(false)
		vim:set_lines({ 'red' })
		assert.same({
			{ vim.api.nvim_get_current_buf() },
		}, get_calls())
		vim:assert_highlights({})
	end)

	it('function returns true', function()
		setup_auto_attach_fn(true)
		vim:set_lines({ 'red' })
		assert.same({
			{ vim.api.nvim_get_current_buf() },
		}, get_calls())
		vim:assert_highlights({
			{ hl = RED, region = { 0, 0, 0, 3 } },
		})
	end)
end)
