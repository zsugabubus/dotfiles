vim.opt.runtimepath:append('..')
vim.cmd.runtime({ args = { 'plugin/commenter.*' } })

local function reset(commentstring)
	package.loaded.commenter = nil
	require('commenter.config').setup({
		keymap = {
			leader = 'gc',
			line = 'gcc',
		},
	})
	vim.o.commentstring = commentstring
end

local function feedkeys(keys)
	return vim.api.nvim_feedkeys(keys, 'xtim', true)
end

local function screen(lines)
	return vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function assert_screen(expected_lines)
	local got = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	return eq(expected_lines, got)
end

test('gcc', {
	{ '/*%s*/', 'abc', '/* abc */' },
	{ '/*%s*/', '/* abc */', 'abc' },
	{ '/*%s*/', '/*abc*/', 'abc' },
	{ '/*%s*/', '/*  abc  */', ' abc ' },
	{ '# %s ', '#  abc ', ' abc ' },
	{ '--%s', 'abc--def', 'abcdef' },
	{ '--%s', 'abc--def--ghi', 'abcdef--ghi' },
}, function(commentstring, original_line, expected_line)
	reset(commentstring)
	screen({
		original_line,
	})
	feedkeys('gcc')
	assert_screen({
		expected_line,
	})
end)

test('2gcc', {
	{ '2gcc' },
	{ 'gc2j' },
	{ '2gcj' },
}, function(keys)
	reset('//%s')
	screen({
		'    abc',
		'  def',
		'    ghi',
	})
	feedkeys(keys)
	assert_screen({
		'  //   abc',
		'  // def',
		'  //   ghi',
	})
end)

function test_skip_empty()
	reset('REM %s')
	screen({
		'  abc',
		'    ',
		'  def',
	})
	feedkeys('2gcc')
	assert_screen({
		'  REM abc',
		'    ',
		'  REM def',
	})
end
