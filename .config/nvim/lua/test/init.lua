#!/usr/bin/luajit
if vim == nil then
	local function shellescape(s)
		return string.format("'%s'", string.gsub(s, "'", [['"'"']]))
	end

	local function luastring(s)
		return string.format('"%s"', string.gsub(s, '[\\"]', '\\%0'))
	end

	local test_arg = '{'
	for _, s in ipairs(arg) do
		test_arg = test_arg .. luastring(s) .. ','
	end
	test_arg = test_arg .. '}'

	local x = os.execute(
		string.format(
			'exec nvim --headless --clean --cmd %s -u %s',
			shellescape('lua test_arg = ' .. test_arg),
			shellescape(arg[0])
		)
	)
	os.exit(
		-- LuaJIT
		x == 0 -- Lua
			or x == true
	)
end

local inspect = vim.inspect
local INSPECT_SINGLE_LINE = { newline = '' }
local SKIP_ERROR = {}

local stack = {
	{
		name = 'test.lua',
		source = 'test.lua',
		line = 0,
	},
}
local total, passed, failed, skipped = 0, 0, 0, 0
local PASS = '\x1b[1;32mPASS\x1b[m'
local FAIL = '\x1b[1;31mFAIL\x1b[m'
local SKIP = '\x1b[1mSKIP\x1b[m'
local WARN = '\x1b[1;33mWARN\x1b[m'

local tty = assert(io.open('/dev/tty', 'w'))

local opts = {
	glob = '**/*.test.lua',
	pattern = '',
	silent = false,
}

local function push(user_depth)
	local info = debug.getinfo(user_depth, 'Sl')
	local entry = {
		source = string.match(info.source, '[^@/][^/]*$'),
		line = info.currentline,
		total = total,
	}
	stack[#stack + 1] = entry
	return entry
end

local function pop()
	stack[#stack] = nil
end

local function print(...)
	return tty:write(...)
end

local function print_location()
	local top = stack[#stack]
	print('[', top.source, ':', top.line, '] ')

	local k = math.min(3, #stack)
	if not stack[k].name then
		k = k - 1
	end
	local n = stack[#stack].name and #stack or #stack - 1

	for i = k, n do
		local entry = stack[i]
		if i > k then
			print(' > ')
		end
		if i == #stack then
			print('\x1b[1m', entry.name, '\x1b[0m')
		else
			print('\x1b[1m', entry.name, '\x1b[0m')
		end
	end

	print(' > ')
end

local function quit(ok)
	return vim.cmd.cquit({
		bang = true,
		count = ok == false and 1 or 0,
	})
end

local function die(user_depth, format, ...)
	push(user_depth)
	print_location()
	print(FAIL, ' ', string.format(format, ...), '\n')
	pop()
	return quit(false)
end

local function parse_args()
	local i = 1

	while i <= #test_arg do
		local opt = test_arg[i]
		i = i + 1

		local function arg()
			local s = test_arg[i]
			i = i + 1
			if not s then
				die(4, 'option %s requires argument', opt)
			end
			return s
		end

		if opt == '-g' then
			opts.glob = arg()
		elseif opt == '-p' then
			opts.pattern = arg()
		elseif opt == '-s' then
			opts.silent = true
		elseif string.match(opt, '^%-') then
			die(3, 'unknown option: %s', opt)
		else
			opts.pattern = opt
		end
	end
end

local function string_or_inspect(x)
	if type(x) == 'string' then
		return x
	else
		return inspect(x)
	end
end

local function print_summary()
	return print(
		string.format(
			'%s\n%s %d passed, %d failed, %d skipped.\n',
			string.rep('=', 30),
			failed == 0 and PASS or FAIL,
			passed,
			failed,
			skipped
		)
	)
end

local function add_test(ok, format, ...)
	if ok then
		total, passed = total + 1, passed + 1
	else
		total, failed = total + 1, failed + 1
	end

	if ok and opts.silent then
		return
	end

	print_location()
	return print(ok and PASS or FAIL, ' ', string.format(format, ...), '\n')
end

local function run_function(user_depth, name, fn)
	local entry = push(user_depth)
	entry.name = name

	local ok, err = pcall(fn)
	if not ok then
		if err ~= SKIP_ERROR then
			add_test(false, 'Unhandled error:\n%s', string_or_inspect(err))
		end
	else
		if entry.total == total then
			add_test(false, 'No tests defined')
		end
	end

	return pop()
end

local function run_file(file)
	return run_function(3, file, function()
		return dofile(file)
	end)
end

local function run_files()
	local files = vim.fn.glob(opts.glob, true, true)

	add_test(#files > 0, '%d files matched %s', #files, inspect(opts.glob))

	for _, file in ipairs(files) do
		run_file(file)
	end
end

function skip(should_skip)
	if stack[#stack].total ~= total then
		push(3)
		add_test(false, 'skip() after test')
		pop()
	end

	if should_skip or should_skip == nil then
		skipped = skipped + 1
		if not opts.silent then
			push(3)
			print_location()
			print(SKIP, '\n')
			pop()
		end
		error(SKIP_ERROR)
	end
end

function it(name, arg1, arg2)
	if not string.match(name, opts.pattern) then
		return
	end

	if arg2 then
		local n = 1
		for _, p in ipairs(arg1) do
			for i = 9, n + 1, -1 do
				if p[i] ~= nil then
					n = i
					break
				end
			end
		end

		local any = false

		for _, p in ipairs(arg1) do
			assert(type(p) == 'table')

			local i = 0
			any = true

			run_function(
				4,
				string.gsub(
					string.find(name, '%%') and name or name .. ' (%0)',
					'%%([s0-9])',
					function(what)
						if what == 's' then
							i = i + 1
							return inspect(p[i], INSPECT_SINGLE_LINE)
						elseif what == '0' then
							local s = {}
							for i = 1, n do
								table.insert(s, inspect(p[i], INSPECT_SINGLE_LINE))
							end
							return table.concat(s, ', ')
						else
							return inspect(p[tonumber(what)], INSPECT_SINGLE_LINE)
						end
					end
				),
				function()
					return arg2(p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9])
				end
			)
		end

		if not any then
			push(3)
			add_test(false, 'No parameters defined')
			pop()
		end
		return
	end

	return run_function(3, name, arg1)
end
test = it
describe = it

function eq(a, b)
	push(3)
	add_test(a == b, 'Expected %s == %s', inspect(a), inspect(b))
	return pop()
end

setmetatable(_G, {
	__newindex = function(_G, k, v)
		if
			type(k) == 'string'
			and (
				string.match(k, '^test_')
				or string.match(k, '^it_')
				or string.match(k, '^describe_')
			)
		then
			return it(k, v)
		else
			push(3)
			print_location()
			print(WARN, ' Global newindex ', inspect(k), '\n')
			pop()
			return rawset(_G, k, v)
		end
	end,
	__index = function(_G, k)
		push(3)
		print_location()
		print(WARN, ' Global index ', inspect(k), '\n')
		pop()
	end,
})

parse_args()
run_files()
print_summary()
quit(failed == 0)
