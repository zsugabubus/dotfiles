local vim = create_vim()

before_each(function()
	local zdotdir = vim.fn.tempname()
	vim.fn.setenv('SHELL', 'sh')
	vim.fn.setenv('ZDOTDIR', zdotdir)
	vim.fn.mkdir(zdotdir)
	vim.fn.chdir(zdotdir)
	vim.fn.writefile({
		'echo junk stdout',
		'hash -d a=/path/to/a',
		'hash -d A=/path/to/A',
		'hash -d ab=/path/to/a/bbb',
		'hash -d Abc123="/path/to/a b c"',
		'hash -d d=$HOME/Downloads',
	}, '.zshrc')
	vim:lua(function()
		_G.vim.api.nvim_create_user_command('X', function(opts)
			_G.args = opts.fargs
		end, { nargs = '*' })
	end)
end)

test('expands while editing', function()
	local function test_case(input, expected)
		vim.api.nvim_input('<Esc>' .. input)
		return assert.same(expected, vim.fn.getcmdtype() .. vim.fn.getcmdline())
	end

	test_case(':X ~a', ':X ~a')
	test_case(':X ~ab', ':X ~ab')
	test_case(':X ~ax', ':X ~ax')
	test_case(':X ~a/', ':X /path/to/a/')
	test_case(':X ~a ', ':X /path/to/a ')
	test_case(':X ~a:', ':X ~a:')
	test_case(':X ~a.', ':X ~a.')
	test_case(':   X   ~a ', ':   X   /path/to/a ')
	test_case(':X ~ab/', ':X /path/to/a/bbb/')
	test_case(':X ~d/', ':X ~/Downloads/')
	test_case(':X ~unknown/', ':X ~unknown/')
	test_case(':X \\~a/', ':X \\~a/')
	test_case(':X ~x/ ~a/', ':X ~x/ ~a/')
	test_case(':call input("")<CR>X ~a/', '@X ~a/')
	test_case([[:lua vim.fn.setreg('"', '~a/')<CR>:X <C-R>"]], ':X /path/to/a/')
end)

test('expands on leave', function()
	local function test_case(input, expected)
		assert.same('n', vim.fn.mode())
		vim.api.nvim_input(input)
		assert.same(
			expected,
			vim:lua(function()
				return _G.args
			end)
		)
	end

	test_case(':X ~Abc123<CR>', { '/path/to/a b c' })
	test_case(':X ~Abc123/d<CR>', { '/path/to/a b c/d' })
	test_case(':lua args=vim.fn.input("")<CR>X ~a/<CR>', 'X ~a/')
end)
