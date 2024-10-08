-- Just for safety.
vim.fn.setenv('TMUX', 'disabled')

local tmux = require('spec.tmux_helper').create_tmux()
local vim = create_vim({
	width = 200,
	isolate = false,
	on_setup = function(vim)
		vim.fn.setenv('TMUX', tmux.get_env())
	end,
})

local function complete(s)
	return vim.fn.getcompletion(s, 'cmdline')
end

local function assert_completes_panes(cmd)
	tmux.new_session('-s', 'comp', 'true')
	tmux.new_window('-t', 'comp', 'true')
	tmux.new_session('-s', 'comp2', 'true')
	tmux.split_window('-t', 'comp2', 'true')
	tmux.new_session('-s', 'u-cant-see-me', 'true')
	tmux.client('attach-session', '-t', 'comp2')

	local all = complete(cmd .. ' ')
	assert.not_same({}, all)
	assert.not_same({}, complete(cmd .. ' @'))
	assert.not_same({}, complete(cmd .. ' %'))
	assert.not_same({}, complete(cmd .. ' {'))
	assert.not_same({}, complete(cmd .. ' !'))
	assert.same(
		{ 'comp:0.0', 'comp:1.0', 'comp2:0.0', 'comp2:0.1' },
		complete(cmd .. ' cmp')
	)

	for _, pane in ipairs(all) do
		tmux.assert_target_exists(pane)
	end
end

before_each(function()
	tmux.start_server()
end)

after_each(function()
	tmux.kill_server()
end)

local CONTENT = { 'a', '', '', 'b' }
local GARBAGE = '#{:,}! % # * | $(true) vim: a $PATH~'

describe(':Tbuffers', function()
	it('without arguments', function()
		vim.cmd.Tbuffers()

		assert.same('tmux://buffers/', vim.fn.bufname())
	end)
end)

describe('tmux://buffers/', function()
	it('reads buffer list', function()
		tmux.set_buffer('list-old', 'old content')
		tmux.set_buffer('list-new', 'new content vim: a')

		vim.cmd.edit('tmux://buffers/')

		local lines = vim:get_lines()
		assert.same('tmux://buffers/list-new\tnew content vim: a', lines[1])
		assert.same('tmux://buffers/list-old\told content', lines[2])

		assert.same('tmuxlist', vim.bo.filetype)
		assert.same('nofile', vim.bo.buftype)
		assert.False(vim.bo.modeline)
		assert.False(vim.bo.swapfile)
		assert.True(vim.bo.readonly)
		vim:assert_messages('')
	end)
end)

describe(':Tbuffer', function()
	it('completes', function()
		tmux.set_buffer('xcomp', 'x')
		tmux.set_buffer('compx', 'x')
		tmux.set_buffer('u-cant-see-me', 'x')

		assert.not_same({}, complete('Tbuffer '))
		assert.same({ 'compx', 'xcomp' }, complete('Tbuffer cmp'))
	end)

	it('errors without arguments', function()
		assert.error_matches(vim.cmd.Tbuffer, 'Wrong number of arguments')
	end)

	it('edits buffer with {buffer-name}', function()
		local buffer_name = 'tbuffer' .. GARBAGE

		vim.cmd.Tbuffer(buffer_name)

		assert.same('tmux://buffers/' .. buffer_name, vim.fn.bufname())
		vim:assert_messages('')
	end)
end)

describe('tmux://buffers/{buffer-name}', function()
	it('reads buffer content', function()
		local buffer_name = 'test' .. GARBAGE
		tmux.set_buffer(buffer_name, 'a\n\n\nb')

		vim.cmd.edit(vim.fn.fnameescape('tmux://buffers/' .. buffer_name))

		assert.same({ 'a', '', '', 'b' }, vim:get_lines())

		assert.False(vim.bo.swapfile)
		vim:assert_messages('')
	end)

	it('reads empty with nonexisting buffer', function()
		vim.cmd.edit('tmux://buffers/does-not-exist')

		assert.same({ '' }, vim:get_lines())
		vim:assert_messages('')
	end)

	it('writes buffer', function()
		local buffer_name = 'write' .. GARBAGE

		tmux.set_buffer(buffer_name .. 'x', 'x')

		vim.cmd.edit(vim.fn.fnameescape('tmux://buffers/' .. buffer_name))
		vim:set_lines(CONTENT)

		assert.True(vim.bo.modified)
		vim.cmd.update()
		assert.False(vim.bo.modified)
		assert.same(CONTENT, tmux.get_buffer_lines(buffer_name))
		vim:assert_messages(string.format('"%s" [New] written', buffer_name))

		vim.cmd.write()
		assert.same(CONTENT, tmux.get_buffer_lines(buffer_name))
		vim:assert_messages(string.format('"%s" written', buffer_name))
	end)
end)

describe(':Twrite', function()
	local function get_top_buffer_name()
		return assert(tmux.list_buffers()[1])
	end

	it('writes automatic buffer without arguments', function()
		vim:set_lines(CONTENT)

		vim.cmd.Twrite()

		local new_buffer_name = get_top_buffer_name()
		assert.matches('^buffer%d*$', new_buffer_name)
		assert.same(CONTENT, tmux.get_buffer_lines(new_buffer_name))
		vim:assert_messages('Buffer written')
	end)

	it('writes named buffer with {buffer-name}', function()
		local buffer_name = 'twrite' .. GARBAGE

		vim:set_lines(CONTENT)

		vim.cmd.Twrite(buffer_name)

		assert.same(CONTENT, tmux.get_buffer_lines(buffer_name))
		vim:assert_messages('Buffer written')
	end)

	it(
		'writes range of lines to named buffer with {buffer-name} and range',
		function()
			local buffer_name = 'twrite-range' .. GARBAGE

			vim:set_lines({ '1', '2', '3', '4' })

			vim.cmd('2Twrite ' .. buffer_name)
			assert.same({ '2' }, tmux.get_buffer_lines(buffer_name))
			vim:assert_messages('Buffer written')

			vim.cmd('2,3Twrite ' .. buffer_name)
			assert.same({ '2', '3' }, tmux.get_buffer_lines(buffer_name))
			vim:assert_messages('Buffer written')

			vim.cmd('%Twrite ' .. buffer_name)
			assert.same({ '1', '2', '3', '4' }, tmux.get_buffer_lines(buffer_name))
			vim:assert_messages('Buffer written')
		end
	)
end)

describe(':Tpanes', function()
	it('edits panes list without arguments', function()
		vim.cmd.Tpanes()

		assert.same('tmux://panes/', vim.fn.bufname())
	end)
end)

describe('tmux://panes/', function()
	it('reads pane list', function()
		tmux.new_session('-s', 'list', '-n', 'first', 'echo')
		tmux.set_pane_title('list:0', 'first')
		tmux.new_window('-t', 'list', '-n', 'second', 'echo')
		tmux.set_pane_title('list:1', 'second')

		vim.cmd.edit('tmux://panes/')

		assert.same({
			'tmux://panes/%0\tlist:0.0\tfirst',
			'tmux://panes/%1\tlist:1.0\tsecond',
		}, vim:get_lines())

		assert.same('tmuxlist', vim.bo.filetype)
		assert.same('nofile', vim.bo.buftype)
		assert.False(vim.bo.modeline)
		assert.False(vim.bo.swapfile)
		assert.True(vim.bo.readonly)
		vim:assert_messages('')
	end)
end)

describe(':Tpane', function()
	it('completes', function()
		assert_completes_panes('Tpane')
	end)

	it('errors without arguments', function()
		assert.error_matches(vim.cmd.Tpane, 'Wrong number of arguments')
	end)

	it('edits pane with {target}', function()
		local target = 'tpane' .. GARBAGE

		vim.cmd.Tpane(target)

		assert.same('tmux://panes/' .. target, vim.fn.bufname())
	end)

	it('edits pane resolved to its id with {target} and bang', function()
		tmux.new_session('-s', 'tpane-bang', 'echo content')
		tmux.client('attach-session', '-t', 'tpane-bang')

		-- Sanity check to see {last} does not exist.
		vim.cmd('Tpane! {last}')
		assert.same('tmux://panes/{last}', vim.fn.bufname())
		assert.same('', vim.fn.getline(1))

		tmux.new_window('-t', 'tpane-bang', 'echo')

		vim.cmd('Tpane! {last}')
		assert.matches('^tmux://panes/%%%d+$', vim.fn.bufname())
		assert.same('content', vim.fn.getline(1))
	end)
end)

describe(':Tlast', function()
	it('edits {last} pane resolved its id without arguments', function()
		tmux.new_session('-s', 'tlast', 'echo content')
		tmux.new_window('-t', 'tlast', 'echo')
		tmux.client('attach-session', '-t', 'tlast')

		vim.cmd.Tlast()

		assert.matches('^tmux://panes/%%%d+$', vim.fn.bufname())
		assert.same('content', vim.fn.getline(1))
	end)
end)

describe('tmux://panes/{target}', function()
	local function force_del_user_command(name)
		vim:vim('command! ' .. name .. ' x')
		vim:vim('delcommand ' .. name)
	end

	after_each(function()
		force_del_user_command('AnsiEsc')
		force_del_user_command('AnsiEscFake')
	end)

	it('reads pane content', function()
		tmux.new_session('-s', 'show', 'yes | head -n100')
		vim.wait(25)

		vim.cmd.edit('tmux://panes/show:')

		local lines = vim:get_lines()
		assert.matches('Pane is dead', table.remove(lines))
		assert.same(100, #lines)

		assert.False(vim.bo.modeline)
		assert.False(vim.bo.swapfile)
		assert.True(vim.bo.readonly)
		vim:assert_messages('')
	end)

	it('errors with invalid {target}', function()
		tmux.new_session('true')

		vim.cmd.edit('tmux://panes/does-not-exist')

		vim:assert_messages("tmux: can't find pane: does-not-exist")
	end)

	it('integrates with :AnsiEsc', function()
		tmux.new_session('-s', 'ansi', 'printf "\\x1b[1mbold"')
		vim.wait(25)

		vim:lua(function()
			_G.vim.api.nvim_create_user_command('AnsiEscFake', function()
				error('unreachable')
			end, {})
		end)

		vim.cmd.edit('tmux://panes/ansi:')

		assert.same('bold', vim.fn.getline(1))

		vim:lua(function()
			_G.vim.api.nvim_create_user_command('AnsiEsc', function()
				_G.vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { 'AnsiEsc:' })
			end, {})
		end)

		vim.cmd.edit()

		assert.same('AnsiEsc:\x1b[1mbold', vim.fn.getline(1))
	end)

	describe(':Tcdhere', function()
		it('cds into cwd of the underlying buffer', function()
			local dir = vim.fn.tempname() .. 'tcdhere'
			vim.fn.mkdir(dir)
			tmux.new_session('-s', 'tcdhere', '-c', dir, 'cat')
			vim.wait(25)

			vim.cmd.edit('tmux://panes/tcdhere:')

			assert.not_same(dir, vim.fn.getcwd())
			vim.cmd.Tcdhere()
			assert.same(dir, vim.fn.getcwd())
			vim:assert_messages('')
		end)
	end)
end)

describe(':Tcd', function()
	it('completes', function()
		assert_completes_panes('Tcd')
	end)

	it('errors without arguments', function()
		assert.error_matches(vim.cmd.Tcd, 'Wrong number of arguments')
	end)

	it('cds into cwd of {target} with {target}', function()
		local dir = vim.fn.tempname() .. 'tcd'
		vim.fn.mkdir(dir)
		tmux.new_session('-s', 'tcd', '-c', dir, 'cat')
		vim.wait(25)

		assert.not_same(dir, vim.fn.getcwd())
		vim.cmd.Tcd('tcd:')
		assert.same(dir, vim.fn.getcwd())
		vim:assert_messages('')
	end)
end)

describe(':Tsplitwindow', function()
	it(
		'does split-window using cwd of the current buffer without arguments',
		function()
			local dir = vim.fn.tempname() .. 'tsplitw'
			vim.fn.mkdir(dir)
			tmux.new_session('-s', 'tsplitw', '-c', '/', 'cat')
			vim.wait(25)

			-- Change cwd of the current window only.
			vim.cmd.lcd(dir)
			-- Sanity check to see that cwd of neovim is different.
			assert.not_same(vim.fn.getcwd(-1, -1), vim.fn.getcwd())
			vim.cmd.Tsplitwindow()

			assert.same(
				dir,
				vim:lua(function()
					return require('tmux').get_cwd('tsplitw:0.1')
				end)
			)
			vim:assert_messages('')
		end
	)
end)

describe('get_cwd()', function()
	it('returns correct directory', function()
		local dir = vim.fn.tempname() .. 'cwd'
		vim.fn.mkdir(dir)

		tmux.new_session('-s', 'cwd', '-c', dir)
		vim.wait(25)

		assert.same(
			dir,
			vim:lua(function()
				return require('tmux').get_cwd('cwd:')
			end)
		)
	end)
end)
