local busted = require('busted')

local function create_assert_snapshot(busted)
	local handler = require('busted.outputHandlers.base')()

	local test_name, per_test_index

	local old_snapshots
	local new_snapshots

	local function serialize_to_lua(x)
		return string.format(
			'return %s',
			string.gsub(
				vim.inspect(x, { indent = '' }),
				'"([^"]*\\n[^"]*)"',
				function(s)
					return string.format('[[\n%s]]', string.gsub(s, '\\n', '\n'))
				end
			)
		)
	end

	local function get_filename(element)
		return string.format('%s.snapshots', element.file[1].name)
	end

	local function get_snapshot_name()
		return string.format(
			'%s%s',
			test_name,
			per_test_index == 1 and '' or string.format('_%d', per_test_index)
		)
	end

	busted.subscribe({ 'suite', 'start' }, function(element)
		if not element.file then
			return
		end

		local ok, result = pcall(dofile, get_filename(element))
		if ok then
			old_snapshots = assert(result)
		else
			old_snapshots = {}
		end
		new_snapshots = {}
	end)

	busted.subscribe({ 'suite', 'end' }, function(element)
		if not element.file then
			return
		end

		local old = serialize_to_lua(old_snapshots)
		local new = serialize_to_lua(new_snapshots)

		if old == new then
			return
		end

		local filename = get_filename(element)

		if not next(new_snapshots) then
			os.remove(filename)
		else
			local f = assert(io.open(filename, 'w'))
			assert(f:write(new))
			assert(f:close())
		end
	end)

	busted.subscribe({ 'test', 'start' }, function(element)
		test_name = handler.getFullName(element)
		per_test_index = 0
	end)

	return function(actual)
		per_test_index = per_test_index + 1

		local name = get_snapshot_name()
		local expected = old_snapshots[name]
		new_snapshots[name] = actual
		if expected then
			return busted.assert.same(expected, actual)
		end
	end
end

local assert_snapshot = create_assert_snapshot(busted)

local ASYNC_API = {
	nvim_get_mode = true,
	nvim_ui_attach = true,
	nvim_input = true,
}

local debug = vim.env.TEST_DEBUG ~= nil

local function print_log(s)
	print(string.format('NVIM REMOTE: %s', s))
end

local function display(value)
	return vim.inspect(value, { indent = '', newline = ' ' })
end

local function display_varargs(...)
	local s = {}
	for i = 1, select('#', ...) do
		table.insert(s, display(select(i, ...)))
	end
	return table.concat(s, ', ')
end

local function display_call(name, ...)
	return string.format('%s(%s)', name, display_varargs(...))
end

local Nvim = {}
Nvim.__index = Nvim

function Nvim.new(cls)
	local self = setmetatable({}, cls)

	self.api = setmetatable({}, {
		__index = function(t, k)
			local function fn(...)
				if debug then
					print_log(display_call(string.format('vim.api.%s', k), ...))
				end

				if not ASYNC_API[k] then
					self:assert_unblocked()
				end

				local result = self:rpc_request(k, ...)
				if result == vim.NIL then
					result = nil
				end
				if debug then
					print_log(string.format('= %s', display(result)))
				end
				return result
			end
			t[k] = fn
			return fn
		end,
	})

	for _, name in ipairs({ 'cmd', 'fn', 'keymap' }) do
		self[name] = self:make_vim_function_redirect(name)
	end

	for _, name in ipairs({ 'v', 'o', 'g', 'go', 'b', 'bo', 'w', 'wo' }) do
		self[name] = self:make_vim_primitive_redirect(name)
	end

	for _, name in ipairs({ 'inspect', 'tbl_map', 'tbl_filter' }) do
		self[name] = vim[name]
	end

	self.wait = function(time)
		self:lua(function(time)
			vim.wait(time)
		end, time)
	end

	return self
end

function Nvim:channel()
	if not self._channel then
		if debug then
			print_log('--- start ---')
		end
		self._channel = vim.fn.jobstart(
			{ 'nvim', '--embed', '--clean', '--cmd', 'set noloadplugins noswapfile' },
			{ rpc = true }
		)
	end
	return self._channel
end

function Nvim:stop()
	if self._channel then
		if debug then
			print_log('--- stop ---')
		end
		vim.fn.jobstop(self._channel)
		self._channel = nil
	end
end

function Nvim:is_running()
	return self._channel ~= nil
end

function Nvim:is_blocking()
	return self.api.nvim_get_mode()['blocking']
end

function Nvim:unblock()
	self.api.nvim_input('<Esc>')
	self:assert_unblocked()
end

function Nvim:assert_unblocked()
	busted.assert.False(self:is_blocking())
end

function Nvim:rpc_request(...)
	return vim.fn.rpcrequest(self:channel(), ...)
end

function Nvim:vim(source)
	return self.api.nvim_exec2(source, { output = true }).output
end

function Nvim:lua(fn, ...)
	return self.api.nvim_exec_lua(string.dump(fn, true), { ... })
end

function Nvim:messages()
	return self:vim('messages')
end

function Nvim:clear()
	self.cmd('%bdelete!|set all&|call setqflist([])|messages clear')
end

function Nvim:save_global_options()
	local state = self:lua(function()
		local GLOBAL = { scope = 'global' }
		local get = vim.api.nvim_get_option_value

		local t = {}
		local output = vim.api.nvim_exec2('set!', { output = true }).output

		for name in string.gmatch(output, '\n[n ][o ]([a-z]+)') do
			t[name] = get(name, GLOBAL)
		end

		return t
	end)

	return function()
		self:lua(function(state)
			local GLOBAL = { scope = 'global' }
			local set = vim.api.nvim_set_option_value

			vim.cmd.set('all&')

			for name, value in pairs(state) do
				set(name, value, GLOBAL)
			end
		end, state)
	end
end

function Nvim:pop_messages()
	local result = self:messages()
	self.cmd('messages clear')
	return result
end

function Nvim:get_lines()
	return self.api.nvim_buf_get_lines(0, 0, -1, false)
end

function Nvim:set_lines(lines)
	self.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

function Nvim:feed(keys)
	self.api.nvim_feedkeys(keys, 'xtim', true)
end

function Nvim:resize(width, height)
	self.api.nvim_ui_try_resize(width, height)
end

function Nvim:screen()
	return self:lua(function()
		local lines = {}

		for y = 1, vim.o.lines do
			local columns = {}
			for x = 1, vim.o.columns do
				table.insert(columns, vim.fn.nr2char(vim.fn.screenchar(y, x)))
			end
			local line = table.concat(columns)
			line = string.gsub(line, ' +$', '')
			table.insert(lines, line)
		end

		return lines
	end)
end

function Nvim:assert_lines(expected)
	busted.assert.same(expected, self:get_lines())
end

function Nvim:assert_messages(expected)
	busted.assert.same(expected, self:pop_messages())
end

function Nvim:assert_screen()
	return assert_snapshot(table.concat(self:screen(), '\n'))
end

function Nvim:make_vim_function_redirect(name)
	local function index_fn(name, k, ...)
		return vim[name][k](...)
	end

	local function call_fn(name, ...)
		return vim[name](...)
	end

	return setmetatable({}, {
		__index = function(t, k)
			local function fn(...)
				return self:lua(index_fn, name, k, ...)
			end
			t[k] = fn
			return fn
		end,
		__call = function(_, ...)
			return self:lua(call_fn, name, ...)
		end,
	})
end

function Nvim:make_vim_primitive_redirect(name)
	local function index_fn(name, k)
		return vim[name][k]
	end

	local function newindex_fn(name, k, v)
		vim[name][k] = v
	end

	return setmetatable({}, {
		__index = function(_, k)
			return self:lua(index_fn, name, k)
		end,
		__newindex = function(_, k, v)
			self:lua(newindex_fn, name, k, v)
		end,
	})
end

function Nvim:load_plugin()
	self:lua(function()
		vim.opt.runtimepath:append('.')
		for _, f in ipairs(vim.fn.glob('plugin/**/*.{lua,vim}', true, true)) do
			vim.cmd.source(f)
		end
	end)
end

function _G.create_vim(opts)
	if type(opts) == 'function' then
		opts = { on_setup = opts }
	end
	opts = opts or {}

	local vim = Nvim:new()

	local function setup()
		vim.api.nvim_ui_attach(opts.width or 80, opts.height or 7, {})
		vim.o.statusline = '%l,%c'
		vim:load_plugin()

		if opts.on_setup then
			opts.on_setup(vim)
		end
	end

	if opts.isolate == false then
		local restore_options

		busted.before_each(function()
			if not vim:is_running() then
				setup()
				restore_options = vim:save_global_options()
			end

			vim:clear()
			restore_options()
		end)
	else
		busted.before_each(function()
			busted.assert.False(vim:is_running())
			setup()
		end)

		busted.after_each(function()
			vim:stop()
		end)
	end

	return vim
end
