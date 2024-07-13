local vim = create_vim()

local function complete(s)
	return vim.fn.getcompletion(s, 'cmdline')
end

local function mkdir(path)
	vim.fn.mkdir(path, 'p')
end

local function mkfile(path, blob)
	vim.fn.writefile(blob or { path .. ' content' }, path, '')
end

local function git(...)
	local output = vim.fn.system({ 'git', '--no-optional-locks', ... })
	if vim.v.shell_error ~= 0 then
		return assert.same({ 0, '' }, { vim.v.shell_error, output })
	end
end

local function git_init()
	local git_dir = vim.fn.tempname()

	vim.fn.setenv('GIT_CONFIG_NOSYSTEM', '1')
	vim.fn.setenv('GIT_CONFIG_GLOBAL', '/dev/null')
	vim.fn.setenv('GIT_CONFIG_SYSTEM', '/dev/null')

	git('init', git_dir)
	vim.fn.chdir(git_dir)

	return git_dir
end

local function git_config(name, value)
	git('config', '--local', name, value)
end

local function git_config_user(email, name)
	git_config('user.email', email or 'a@b.com')
	git_config('user.name', name or 'Test')
end

local function git_add()
	git('add', '.')
end

local function git_commit(message)
	git('commit', '--allow-empty', '-m', message or 'Initial commit')
end

describe(':Gcd', function()
	local git_dir

	before_each(function()
		git_dir = git_init()
		mkfile('foo')
		mkdir('a/b/c')
		mkdir('d')
		vim.fn.chdir('a/b/c')
	end)

	it('completes', function()
		assert.same({ 'a/', 'd/' }, complete('Gcd '))
		assert.same({ 'a/b/' }, complete('Gcd a/'))
	end)

	it('chdirs to root', function()
		vim.cmd.Gcd()
		assert.same(git_dir, vim.fn.getcwd())
	end)

	it('chdirs to directory', function()
		vim.cmd.Gcd('a/b')
		assert.same(git_dir .. '/a/b', vim.fn.getcwd())
	end)
end)

describe(':Gshow', function()
	it('completes', function()
		git_init()
		git_config_user()
		mkdir('a')
		mkfile('a/file')
		git_add()
		git_commit()
		git('switch', '-C', 'branch')
		git('tag', 'tag')

		-- Commits.
		assert.same({ 'branch', 'master', 'tag', 'HEAD' }, complete('Gshow '))
		assert.same({ 'master' }, complete('Gshow m'))
		assert.same({ 'tag' }, complete('Gshow t'))
		assert.same({ 'heads/branch', 'heads/master' }, complete('Gshow heads/'))
		assert.same({ 'tags/tag' }, complete('Gshow tags'))
		assert.same(
			{ 'refs/heads/branch', 'refs/heads/master', 'refs/tags/tag' },
			complete('Gshow r')
		)

		-- Paths.
		assert.same({ 'master:a/' }, complete('Gshow master:'))
		assert.same({ 'master:a/file' }, complete('Gshow master:a/'))
	end)

	it('edits git://', function()
		vim.cmd.Gshow()
		assert.same('git://@', vim.fn.bufname())

		vim.cmd.Gshow('@:a/b/c')
		assert.same('git://@:a/b/c', vim.fn.bufname())

		vim.cmd.Gshow('@~1^2~3:a/b/c')
		assert.same('git://@~1^2~3:a/b/c', vim.fn.bufname())

		vim.cmd.Gshow('@:a %!*')
		assert.same('git://@:a %!*', vim.fn.bufname())
	end)
end)

describe('git://', function()
	before_each(function()
		git_init()
		git_config_user()
		mkdir('a/b')
		mkfile('a/b/file.c')
		git_add()
		git_commit()
	end)

	it('reads commit', function()
		vim.cmd.edit('git://@')
		assert.matches('^commit.*HEAD', vim.fn.getline(1))
		assert.same('git', vim.bo.filetype)
	end)

	it('shows full stat names', function()
		local f = string.rep('a', 100)
		mkfile(f)
		git_add()
		git_commit()

		vim.cmd.edit('git://@')
		assert.True(vim.fn.search(f .. ' (new)') > 0)
	end)

	it('reads blob', function()
		vim.cmd.edit('git://@:a/b/file.c')
		vim:assert_lines({ 'a/b/file.c content' })
		assert.same('c', vim.bo.filetype)
	end)

	it('reads tree', function()
		vim.cmd.edit('git://@:')
		vim:assert_lines({
			'tree @:',
			'',
			'a/',
		})
		assert.same('git', vim.bo.filetype)
		vim:feed('3Ggf')
		assert.same('git://@:a/', vim.fn.bufname())
	end)

	it('shows error', function()
		vim.cmd.edit('git://foo')
		vim:assert_lines({ "fatal: bad revision 'foo'" })
		assert.same('giterror', vim.bo.filetype)
	end)

	it('goes to child', function()
		vim.cmd.edit('git://@:a/')
		vim:feed('3Ggf')
		assert.same('git://@:a/b/', vim.fn.bufname())
		vim:feed('3Ggf')
		assert.same('git://@:a/b/file.c', vim.fn.bufname())
	end)

	it('goes to parent tree', function()
		vim.cmd.edit('git://@:a/b/')
		vim:feed('u')
		assert.same('git://@:a/', vim.fn.bufname())
		vim:feed('u')
		assert.same('git://@:', vim.fn.bufname())
		vim:feed('u')
		assert.same('git://@:', vim.fn.bufname())
	end)
end)

describe(':Gedit', function()
	local git_dir

	before_each(function()
		git_dir = git_init()
		mkfile('foo')
		mkfile('bar')
		mkdir('a/b/c')
		mkdir('d')
		vim.fn.chdir('a/b/c')
	end)

	it('completes', function()
		assert.same({ 'a/', 'bar', 'd/', 'foo' }, complete('Gedit '))
		assert.same({ 'foo' }, complete('Gedit f'))
		assert.same({ 'a/' }, complete('Gedit a'))
		assert.same({ 'a/b/' }, complete('Gedit a/'))
	end)

	it('edits file', function()
		vim.cmd.Gedit('foo')
		assert.same(git_dir .. '/foo', vim.fn.expand('%'))
	end)
end)

describe(':Gdiff', function()
	it('completes', function()
		git_init()
		git_config_user()
		git_commit()
		assert.same({ 'master', 'HEAD' }, complete('Gdiff '))
		assert.same({ 'master' }, complete('Gdiff m'))
	end)

	it('shows diff against staged', function()
		git_init()

		vim.cmd.edit('file')
		vim.cmd.Gdiff()

		assert.same('file', vim.fn.bufname())
		assert.True(vim.wo.diff)

		vim.cmd.wincmd('p')

		assert.same('git://:0:file', vim.fn.bufname())
		assert.True(vim.wo.diff)
	end)

	it('shows diff against commit', function()
		git_init()

		vim.cmd.edit('file')
		vim.cmd.Gdiff('@~4')
		vim.cmd.wincmd('p')
		assert.same('git://@~4:file', vim.fn.bufname())
	end)
end)

describe(':Gblame', function()
	it('splits git-blame://', function()
		git_init()

		vim.cmd.edit(vim.fn.fnameescape('a %'))
		local a = vim.fn.expand('%:p')
		vim.cmd.Gblame()
		assert.same('git-blame://-:' .. a, vim.fn.bufname())
		vim.cmd.wincmd('p')
		assert.same('a %', vim.fn.bufname())

		vim.cmd.edit(vim.fn.fnameescape('git://@~4:a/b % < *'))
		vim.cmd.Gblame()
		assert.same('git-blame://@~4:a/b % < *', vim.fn.bufname())
	end)

	it('binds scroll and cursor', function()
		local get_cursor = vim.api.nvim_win_get_cursor

		git_init()
		local t = {}
		for i = 1, 100 do
			table.insert(t, string.rep(i, 100))
		end
		mkfile('a', t)
		git_add()
		git_config_user()
		git_commit()

		vim.cmd.edit('a')
		vim.wo.wrap = false
		vim:feed('Go99999')
		vim:feed('50Gzt')

		local content_win = vim.api.nvim_get_current_win()
		local content_view = vim.fn.winsaveview()

		vim.cmd.Gblame()

		local blame_win = vim.api.nvim_get_current_win()

		vim.cmd.wincmd('p')
		assert.same(content_view, vim.fn.winsaveview())
		vim.cmd.wincmd('p')
		assert.same(vim.fn.line('w0'), content_view.topline)
		vim.cmd.wincmd('p')

		assert.True(vim.wo[content_win].scrollbind)
		assert.True(vim.wo[blame_win].scrollbind)
		assert.False(
			vim.api.nvim_get_option_value('scrollbind', { scope = 'global' })
		)

		assert.same({ 50, 4 }, get_cursor(content_win))
		assert.same({ 50, 0 }, get_cursor(blame_win))

		vim.cmd.wincmd('p')
		vim:feed('20G')
		assert.same({ 20, 0 }, get_cursor(blame_win))
		assert.same({ 20, 4 }, get_cursor(content_win))

		vim.cmd.wincmd('p')
		vim:feed('99999G')
		assert.same({ 101, 4 }, get_cursor(content_win))
		assert.same({ 100, 0 }, get_cursor(blame_win))

		local content_view = vim.fn.winsaveview()
		vim.cmd.wincmd('p')
		local blame_view = vim.fn.winsaveview()
		vim.cmd.edit()

		assert.same(blame_view, vim.fn.winsaveview())
		vim.cmd.wincmd('p')
		content_view.lnum = 100
		assert.same(content_view, vim.fn.winsaveview())

		vim.cmd.wincmd('p')
		vim.cmd.close()
		assert.same(content_view, vim.fn.winsaveview())
		vim:feed('1G')
		assert.same('a', vim.fn.bufname())
		assert.False(vim.wo.scrollbind)
	end)

	it('commit preview follows cursor', function()
		git_init()
		git_config_user()
		mkfile('a', { 'a', 'a', 'a' })
		git_add()
		git_commit()
		mkfile('a', { 'a', 'a', 'b' })
		git_add()
		git_commit()

		vim.cmd.edit('a')
		vim.cmd.Gblame()

		local function get_preview_bufname()
			vim.cmd.wincmd('P')
			local s = vim.fn.bufname()
			vim.cmd.wincmd('p')
			return s
		end

		vim:feed('G')
		assert.error_matches(get_preview_bufname, 'no preview window')
		vim:feed('gg')

		vim:feed('gf')

		local first = get_preview_bufname()
		vim:feed('j')
		local second = get_preview_bufname()
		vim:feed('j')
		local third = get_preview_bufname()

		assert.same(first, second)
		assert.not_same(first, third)
	end)
end)

describe('git-blame://', function()
	local function commit(who, blob)
		mkfile('a', blob)
		git_add()
		git_config_user(nil, who)
		git_commit()
	end

	local function assert_blame(who1, who2)
		local function pat(who)
			return '^%x+ %d%d%d%d%-%d%d%-%d%d ' .. who .. '$'
		end

		local lines = vim.fn.getline(1, '$')
		assert.same(2, #lines)
		assert.matches(pat(who1), lines[1])
		assert.matches(pat(who2), lines[2])

		assert.same(
			#'0000000 0000-00-00 ' + math.max(#who1, #who2),
			vim.api.nvim_win_get_width(0)
		)
	end

	it('reads blame', function()
		git_init()
		commit('Alice', { 'a', 'a' })
		commit('Bob', { 'a', 'b' })
		vim.cmd.vsplit('git-blame://-:a')
		assert_blame('Alice', 'Bob')

		commit('Christy', { 'c', 'c' })
		mkfile('a', { 'c', 'd' })
		vim.cmd.edit()
		assert_blame('Christy', 'Not Committed Yet')

		vim.cmd.vsplit('git-blame://@~:a')
		assert_blame('Alice', 'Bob')
	end)

	it('previews commit', function()
		git_init()
		commit('Alice', { 'a', 'a' })
		vim.cmd.vsplit('git-blame://-:a')
		vim:feed('$gf')
		assert.same('git-blame://-:a', vim.fn.bufname())
		vim.cmd.wincmd('P')
		assert.matches('^git://%x+$', vim.fn.bufname())
	end)

	it('bufloadable', function()
		git_init()
		commit('Alice', { 'a', 'a' })
		local buf = vim.fn.bufnr('git-blame://-:a', true)
		vim.fn.bufload(buf)
		assert.same(2, vim.api.nvim_buf_line_count(buf))
	end)
end)

describe(':Gsign', function()
	it('maybe works', function()
		vim.cmd.Gsign()
	end)
end)

describe(':Glog', function()
	it('completes', function()
		git_init()
		git_config_user()
		git_commit()
		assert.same({ 'master', 'HEAD' }, complete('Gdiff '))
		assert.same({ 'master' }, complete('Gdiff m'))
	end)

	it('edits git-log://', function()
		git_init()
		git_config_user()
		mkfile('a', { '1', '2' })
		git_add()
		git_commit()
		mkfile('a', { '1', '2', '3', '4', '5' })
		git_add()
		git_commit()

		vim.cmd.Glog()
		assert.same('git-log://@', vim.fn.bufname())

		vim.cmd.Glog('master')
		assert.same('git-log://master', vim.fn.bufname())

		vim.cmd.Glog('@:% < *')
		assert.same('git-log://@:% < *', vim.fn.bufname())

		vim.cmd.edit('a')
		vim.cmd('2,4Glog @')
		assert.same('git-log://@', vim.fn.bufname())

		vim.cmd.edit('a')
		vim.cmd('2,4Glog')
		assert.same('git-log://@:a:2-4', vim.fn.bufname())

		vim.cmd.edit('git://@~:a')
		vim.cmd('1Glog')
		assert.same('git-log://@~:a:1-1', vim.fn.bufname())

		vim.cmd.edit('a')
		vim.cmd('%Glog')
		assert.same('git-log://@:a:1-5', vim.fn.bufname())
	end)
end)

describe('git-log://', function()
	local function git_log_vim(s)
		git_config(
			'alias.log-vim',
			s or 'log --pretty="format:%C(bold red)%d%C(reset) %s"'
		)
	end

	it('reads commit log', function()
		git_init()
		git_config_user()
		git('switch', '-C', 'test')
		git_commit()
		git('switch', '-C', 'master')
		git_commit()

		vim.cmd.edit('git-log://test')
		assert.matches('^commit', vim.fn.getline(1))
		assert.matches('Initial commit', vim.fn.getline('$'))

		git_log_vim()
		vim.cmd.edit()
		vim:assert_lines({ ' (test) Initial commit' })
	end)

	it('reads file commit log', function()
		git_init()
		git_config_user()
		mkfile('a', { 'a-1', 'a-2', 'a-3', 'a-4' })
		mkfile('b', { 'b-1', 'b-2' })
		git_add()
		git_commit()

		vim.fn.mkdir('d')
		vim.fn.chdir('d')

		local function f()
			vim:vim([[let xs=[]|%s/\v[ab]-.$/\=add(xs,submatch(0))/n]])
			return vim.g.xs
		end

		vim.cmd.edit('git-log://@:.')
		assert.same({ 'a-1', 'a-2', 'a-3', 'a-4', 'b-1', 'b-2' }, f())

		vim.cmd.edit('git-log://@:a')
		assert.same({ 'a-1', 'a-2', 'a-3', 'a-4' }, f())

		vim.cmd.edit('git-log://@:a:2-3')
		assert.same({ 'a-2', 'a-3' }, f())
	end)

	it('integrates with :AnsiEsc', function()
		vim:lua(function()
			_G.vim.api.nvim_create_user_command('AnsiEscFake', function()
				error('unreachable')
			end, {})
		end)

		git_init()
		git_log_vim()
		git_config_user()
		git_commit()
		vim.cmd.edit('git-log://@')

		vim:assert_lines({ ' (HEAD -> master) Initial commit' })

		vim:lua(function()
			local vim = _G.vim
			vim.api.nvim_create_user_command('AnsiEsc', function()
				vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { 'AnsiEsc:' })
			end, {})
		end)

		vim.cmd.edit()
		assert.matches('^AnsiEsc:.*\x1b.*Initial commit', vim.fn.getline(1))
	end)

	it('previews commit', function()
		git_init()
		git_log_vim('log --oneline')
		git_config_user()
		git_commit()
		vim.cmd.edit('git-log://@')
		vim:feed('gf')
		assert.same('git-log://@', vim.fn.bufname())
		vim.cmd.wincmd('P')
		assert.matches('^git://%x+$', vim.fn.bufname())
	end)

	it('folds', function()
		vim.cmd.edit('git-log://@')
		assert.same('expr', vim.wo.foldmethod)
	end)
end)

describe('git_status()', function()
	local function git_status()
		return vim:lua(function()
			return _G.git_status()
		end)
	end

	local function statusline()
		vim.o.statusline = '%{v:lua.git_status()}'
	end

	local function wait()
		_G.vim.wait(25)
	end

	local function wait2()
		-- fs_event() has a 100ms debounce.
		_G.vim.wait(125)
	end

	before_each(function()
		git_init()
	end)

	it('shows bare', function()
		git_config('core.bare', 'true')
		statusline()
		wait()
		assert.same('BARE:master', git_status())
	end)

	it('shows head', function()
		statusline()
		wait2()
		assert.same('master', git_status())
		git('switch', '-C', 'new')
		wait2()
		assert.same('new', git_status())
	end)

	it('shows detached head; hash', function()
		statusline()
		git_config_user()
		git_commit()
		git_commit()
		git('checkout', '@~')
		git('branch', '-D', 'master')
		wait2()
		assert.matches('^detached %x+$', git_status())
	end)

	it('shows detached head; symbolic name', function()
		statusline()
		git_config_user()
		git_commit()
		git_commit()
		git('checkout', '@~')
		wait2()
		assert.same('detached master~1', git_status())
	end)

	it('shows modified', function()
		statusline()
		git_config_user()
		mkfile('a')
		git_add()
		git_commit()
		mkfile('a', { '' })
		git('update-index', '-q', '--refresh')
		wait2()
		assert.same('master*', git_status())
	end)

	it('shows staged', function()
		statusline()
		mkfile('new')
		git_add()
		wait()
		assert.same('master+', git_status())
	end)

	it('shows stashed', function()
		statusline()
		git_config_user()
		git_commit()
		mkfile('a')
		git_add()
		git('stash')
		wait2()
		assert.same('master$', git_status())
		mkfile('b')
		git_add()
		git('stash')
		wait2()
		assert.same('master$2', git_status())
	end)

	it('shows rebase', function()
		statusline()
		git_config_user()
		git_commit()
		git_commit()
		git(
			'-c',
			'core.editor=sed -i s/^pick/edit/',
			'rebase',
			'--interactive',
			'--root'
		)
		wait2()
		assert.same('detached master~1|REBASE 1/2', git_status())
		git('rebase', '--continue')
		wait2()
		assert.same('detached master|REBASE 2/2', git_status())
		git('rebase', '--continue')
		wait2()
		assert.same('master', git_status())
	end)

	it('shows cherry-pick', function()
		statusline()
		git_config_user()
		git_commit()
		assert.error_matches(function()
			git('cherry-pick', '@')
		end, 'previous cherry%-pick is now empty')
		wait2()
		assert.same('master|CHERRY-PICK', git_status())
		git('cherry-pick', '--skip')
		wait2()
		assert.same('master', git_status())
	end)

	it('shows bisect', function()
		statusline()
		git_config_user()
		git_commit()
		git('bisect', 'start')
		wait2()
		assert.same('master|BISECT', git_status())
		git('bisect', 'reset')
		wait2()
		assert.same('master', git_status())
	end)

	it('shows revert', function()
		statusline()
		git_config_user()
		mkfile('a', { 'x' })
		git_add()
		git_commit()
		mkfile('a', { 'y' })
		git_add()
		git_commit()
		assert.error_matches(function()
			git('revert', '@~')
		end, 'CONFLICT')
		wait2()
		assert.same('master|REVERT', git_status())
		git('revert', '--abort')
		wait2()
		assert.same('master', git_status())
	end)

	it('shows merge', function()
		statusline()
		git_config_user()
		mkfile('a', { 'x' })
		git_add()
		git_commit()
		git('switch', '--orphan', 'master2')
		mkfile('a', { 'y' })
		git_add()
		git_commit()
		assert.error_matches(function()
			git('merge', '--allow-unrelated-histories', 'master')
		end, 'CONFLICT')
		wait2()
		assert.same('master2+*|MERGE', git_status())
		git('merge', '--abort')
		wait2()
		assert.same('master2', git_status())
	end)

	it('shows remote', function()
		statusline()
		git_config_user()
		for _ = 1, 5 do
			git_commit()
		end
		git('update-ref', 'refs/remotes/origin/remote', '@~2')
		git('remote', 'add', 'origin', 'url')
		git('switch', '-C', 'local')
		git('branch', '--set-upstream-to', 'origin/remote')

		local function test_case(commit, expected)
			git('reset', commit)
			wait2()
			return assert.same(expected, git_status())
		end

		test_case('master~4', 'local<2')
		test_case('master~3', 'local<')
		test_case('master~2', 'local=')
		test_case('master~1', 'local>')
		test_case('master', 'local>2')
	end)
end)

describe('git filetype', function()
	it('folds correctly', function()
		git_init()
		git_config_user()
		mkdir('a')
		mkfile('a/b', _G.vim.split('XXXXXXXX', ''))
		git_add()
		git_commit()
		mkfile('a/b', _G.vim.split('aXXXXXXXXb', ''))
		mkfile('x', { 'x' })
		git_add()
		git_commit()

		vim.cmd.Gshow()
		assert.same('git', vim.bo.filetype)

		-- Not folded by default.
		for i = 1, vim.fn.line('$') do
			assert.same(-1, vim.fn.foldclosedend(i))
		end

		-- "diff --git"
		vim:feed('zM')
		for i = 1, 13 do
			assert.same(-1, vim.fn.foldclosedend(i))
		end
		assert.same(27, vim.fn.foldclosedend(14))
		assert.same(34, vim.fn.foldclosedend(28))

		-- "@@"
		vim:feed('zr')
		for i = 14, 17 do
			assert.same(-1, vim.fn.foldclosedend(i))
		end
		assert.same(22, vim.fn.foldclosedend(18))
		assert.same(27, vim.fn.foldclosedend(23))
		for i = 28, 32 do
			assert.same(-1, vim.fn.foldclosedend(i))
		end
		assert.same(34, vim.fn.foldclosedend(33))

		-- No more folds.
		vim:feed('zr')
		for i = 1, vim.fn.line('$') do
			assert.same(-1, vim.fn.foldclosedend(i))
		end
	end)
end)

describe('gitrebase filetype', function()
	before_each(function()
		vim.bo.filetype = 'gitrebase'
	end)

	it('changes command', function()
		local function test_case(keys, command)
			vim:set_lines({
				'xxx 0 A',
				'xxx 0 B',
				'xxx 0 C',
				'xxx 0 D',
			})
			vim:feed('gg' .. keys)
			vim:assert_lines({
				command .. ' 0 A',
				'xxx 0 B',
				'xxx 0 C',
				'xxx 0 D',
			})
			vim:feed('j.')
			vim:assert_lines({
				command .. ' 0 A',
				command .. ' 0 B',
				'xxx 0 C',
				'xxx 0 D',
			})
		end

		test_case('cd', 'drop')
		test_case('ce', 'edit')
		test_case('cf', 'fixup')
		test_case('cp', 'pick')
		test_case('cr', 'reword')
		test_case('cs', 'squash')
	end)

	it('previews commit; gf', function()
		vim:set_lines({ '0000' })
		vim:feed('gf')
		vim.cmd.wincmd('P')
		assert.same('git://0000', vim.fn.bufname())
	end)

	it('previews commit; <CR>', function()
		vim:set_lines({ '0000 xxx' })
		vim:feed('$\r')
		vim.cmd.wincmd('P')
		assert.same('git://0000', vim.fn.bufname())
	end)
end)

describe('<Plug>(git-goto-file)', function()
	before_each(function()
		vim.keymap.set('n', 's', '<Plug>(git-goto-file)')
	end)

	it('edits commit', function()
		vim:set_lines({ 'abcdef' })
		vim:feed('s')
		assert.same('git://abcdef', vim.fn.bufname())
	end)

	context('in git diff', function()
		before_each(function()
			git_init()
			git_config_user()
			mkdir('a')
			mkfile('a/b', _G.vim.split('XXXXXXXXabcdddeg', ''))
			git_add()
			git_commit()
			mkfile('a/b', _G.vim.split('yyyyXXXXXXXXaaaabcdefg', ''))
			git_add()
			git_commit()

			vim.cmd.Gshow()
		end)

		it('edits stat file', function()
			vim:feed('10Gs')
			assert.matches('git://%x*:a/b', vim.fn.bufname())
			assert.same(22, vim.fn.line('$'))
			assert.same(1, vim.fn.line('.'))
		end)

		it('edits context line', function()
			vim:feed('Gs')
			assert.matches('git://%x*:a/b', vim.fn.bufname())
			assert.same(22, vim.fn.line('$'))
			assert.same(22, vim.fn.line('.'))
		end)

		it('edits destination line', function()
			vim:feed('Gks')
			assert.matches('git://%x*:a/b', vim.fn.bufname())
			assert.same(22, vim.fn.line('$'))
			assert.same(21, vim.fn.line('.'))
		end)

		it('edits source line', function()
			vim:feed('G3ks')
			assert.matches('git://%x*~:a/b', vim.fn.bufname())
			assert.same(16, vim.fn.line('$'))
			assert.same(14, vim.fn.line('.'))
		end)
	end)

	it('falls back to gf', function()
		vim:set_lines({ 'a/b/c' })
		vim:feed('s')
		assert.same([[E447: Can't find file "a/b/c" in path]], vim.v.errmsg)
	end)
end)
