vim.opt.runtimepath:append('..')
vim.cmd.runtime({ args = { 'plugin/commenter.*' } })

local function reset(commentstring)
	package.loaded.commenter = nil
	vim.keymap.set('', 'gc', '<Plug>(commenter)')
	vim.keymap.set('', 'gcc', '<Plug>(commenter-current-line)')
	vim.o.commentstring = commentstring
end

local function feedkeys(keys)
	return vim.api.nvim_feedkeys(keys, 'xtim', true)
end

local function screen(lines)
	return vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

test('toggle single line', {
	{ '/*%s*/', 'abc', '/* abc */' },
	{ '/*%s*/', '/* abc */', 'abc' },
	{ '/*%s*/', '/*abc*/', 'abc' },
	{ '/*%s*/', '/*  abc  */', ' abc ' },
	{ '/*%s*/', '/**//*def*/', '//*def' }, -- BAD
	{ '/*%s*/', '/* *//*def*/', '/*def*/' },
	{ '/*%s*/', '/*** abc ***/', 'abc' },
	{ '//%s', '//// abc', 'abc' },
	{ '# %s ', '#  abc ', ' abc ' },
	{ '--%s', 'abc--def', 'abcdef' },
	{ '--%s', 'abc--def--ghi', 'abcdef--ghi' },
	{ '//%s', '', '' },
	{ '//%s', ' ', ' ' },
}, function(commentstring, original_line, expected_line)
	reset(commentstring)
	screen({
		original_line,
	})
	feedkeys('gcc')
	assert.screen({
		expected_line,
	})
end)

test('toggle multi line', {
	{ '4gcc' },
	{ 'gc4j' },
	{ '4gcj' },
}, function(keys)
	local ORIGINAL = {
		'    aaa',
		'',
		'     ',
		'  bbb',
		'\t   ccc',
	}

	local COMMENTED = {
		'  //   aaa',
		'',
		'     ',
		'  // bbb',
		'\t //   ccc',
	}

	reset('//%s')
	screen(ORIGINAL)
	feedkeys(keys)
	assert.screen(COMMENTED)
	feedkeys(keys)
	assert.screen(ORIGINAL)
end)

function test_comment_all()
	reset('*%s')
	screen({
		'',
		'aaa',
		'*bbb',
	})
	feedkeys('2gcc')
	assert.screen({
		'',
		'* aaa',
		'* *bbb',
	})
end

function test_uncomment_all()
	reset('*%s')
	screen({
		'',
		'* aaa',
		'* *bbb',
		'ccc',
	})
	feedkeys('3gcc')
	assert.screen({
		'',
		'aaa',
		'*bbb',
		'ccc'
	})
end
