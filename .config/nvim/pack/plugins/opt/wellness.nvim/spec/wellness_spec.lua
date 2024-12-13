local vim = create_vim({
	isolate = false,
	on_setup = function(vim)
		local plugin = vim.fn.tempname()
		vim.fn.mkdir(plugin .. '/lua/test', 'p')
		vim.fn.writefile({
			'health = vim.health',
			'return { check = function() _G.check() end }',
		}, plugin .. '/lua/test/health.lua')
		vim.go.runtimepath = vim.go.runtimepath .. ',' .. plugin
	end,
})

local function assert_health(expected_output, check)
	vim:lua(function(check)
		_G.check = loadstring(check)
	end, string.dump(check))

	vim.cmd.checkhealth('test')

	local output = vim.fn.getline(5, vim.fn.line('$') - 1)
	assert.same(expected_output, output)
end

describe('validate()', function()
	it('prints ok', function()
		assert_health({
			[[- OK `a_AHZ_059[""]["a b\n"][0][<function>][<table>].a` validated (a `nil` value)]],
		}, function()
			local path = { 'a_AHZ_059', '', 'a b\n', 0, function() end, {}, 'a' }
			health.validate(path, nil, function()
				return Nil
			end)
		end)
	end)

	it('prints error', function()
		assert_health({
			'- ERROR Expected `a.b.c[1].d` to be a `number`, but got a `boolean` value',
			'- WARNING Unknown field `e` in `a.b.c[1]`',
			'  - ADVICE:',
			'    - Did you mean: `d`',
		}, function()
			health.validate({ 'a', 'b' }, { c = { { d = true, e = 0 } } }, function()
				return Table({ c = Array(Table({ d = Number })) })
			end)
		end)
	end)
end)

describe('validate_path()', function()
	it('evaluates dotted path', function()
		assert_health({
			[[- OK `x.y.z` validated (a `number` value)]],
		}, function()
			x = { y = { z = 0 } }
			health.validate_path('x.y.z', function()
				return Number
			end)
		end)
	end)
end)

describe('Nil', function()
	it('validates type', function()
		assert_health({
			'- ERROR Expected `` to be a `nil`, but got a `boolean` value',
			'- OK `` validated (a `nil` value)',
		}, function()
			local function schema()
				return Nil
			end
			health.validate({}, false, schema)
			health.validate({}, nil, schema)
		end)
	end)
end)

describe('Boolean', function()
	it('validates type', function()
		assert_health({
			'- ERROR Expected `` to be a `boolean`, but got a `nil` value',
			'- OK `` validated (a `boolean` value)',
		}, function()
			local function schema()
				return Boolean
			end
			health.validate({}, nil, schema)
			health.validate({}, false, schema)
		end)
	end)
end)

describe('String', function()
	it('validates type', function()
		assert_health({
			'- ERROR Expected `` to be a `string`, but got a `nil` value',
			'- OK `` validated (a `string` value)',
		}, function()
			local function schema()
				return String
			end
			health.validate({}, nil, schema)
			health.validate({}, '', schema)
		end)
	end)
end)

describe('Number', function()
	it('validates type', function()
		assert_health({
			'- ERROR Expected `` to be a `number`, but got a `nil` value',
			'- OK `` validated (a `number` value)',
		}, function()
			local function schema()
				return Number
			end
			health.validate({}, nil, schema)
			health.validate({}, 0, schema)
		end)
	end)
end)

describe('Function', function()
	it('validates type', function()
		assert_health({
			'- ERROR Expected `` to be a `function`, but got a `nil` value',
			'- OK `` validated (a `function` value)',
		}, function()
			local function schema()
				return Function
			end
			health.validate({}, nil, schema)
			health.validate({}, function() end, schema)
		end)
	end)
end)

describe('Table', function()
	it('validates type', function()
		assert_health({
			'- ERROR Expected `` to be a `table`, but got a `nil` value',
			'- OK `` validated (a `table` value)',
		}, function()
			local function schema()
				return Table({})
			end
			health.validate({}, nil, schema)
			health.validate({}, {}, schema)
		end)
	end)

	it('validates fields', function()
		assert_health({
			'- ERROR Expected `b` to be a `boolean`, but got a `nil` value',
			'- ERROR Expected `f` to be a `function`, but got a `nil` value',
			'- ERROR Expected `n` to be a `number`, but got a `nil` value',
			'- ERROR Expected `s` to be a `string`, but got a `nil` value',
			'- WARNING Unknown field `d` in `t`',
			'  - ADVICE:',
			'    - Did you mean: `a`, `b`, `c`',
			'- WARNING Unknown fields `d`, `e` in `t2`',
			'  - ADVICE:',
			'    - Did you mean: `a`',
		}, function()
			health.validate({}, { t = { d = 0 }, t2 = { d = 0, e = 0 } }, function()
				return Table({
					s = String,
					n = Number,
					b = Boolean,
					f = Function,
					t = Table({ a = Nil, b = Nil, c = Nil }),
					t2 = Table({ a = Nil }),
				})
			end)
		end)
	end)

	it('validates tuple', function()
		assert_health({
			'- ERROR Expected `[2]` to be a `number`, but got a `string` value',
			'- WARNING Unknown fields `3`, `d` in ``',
			'  - ADVICE:',
			'    - Did you mean: `1`, `2`',
		}, function()
			health.validate({}, { '', '', true, d = 0 }, function()
				return Table({ String, Number })
			end)
		end)
	end)
end)

describe('Array', function()
	it('validates type', function()
		assert_health({
			'- ERROR Expected `` to be a `table`, but got a `nil` value',
			'- OK `` validated (a `table` value)',
		}, function()
			local function schema()
				return Array(Nil)
			end
			health.validate({}, nil, schema)
			health.validate({}, {}, schema)
		end)
	end)

	it('validates fields', function()
		assert_health({
			'- ERROR Expected `[2][1]` to be a `string`, but got a `boolean` value',
			'- WARNING Unknown index `x` in `[3]`',
			'- WARNING Unknown indexes `0`, `1000` in `[4]`',
			'- WARNING Unknown index `1.5` in `[5]`',
		}, function()
			health.validate({}, {
				{},
				{ true, '' },
				{ '', x = 0 },
				{ [0] = 0, [1000] = 0 },
				{ '', '', [1.5] = '' },
			}, function()
				return Array(Array(String))
			end)
		end)
	end)
end)

describe('Union', function()
	it('validates primitives', function()
		assert_health({
			'- ERROR Expected `[1]` to be a `boolean|number|string`, but got a `table` value',
			'- ERROR Expected `[5]` to be a `boolean|number|string`, but got a `table` value',
		}, function()
			health.validate({}, { {}, true, 0, '', {} }, function()
				return Array(Boolean / Number / String)
			end)
		end)
	end)

	it('validates type error', function()
		assert_health({
			'- ERROR Expected `` to be a `nil|table|(nil)[]|nil`, but got a `number` value',
		}, function()
			health.validate({}, 0, function()
				return Nil / Table({}) / Array(Nil) / Nil
			end)
		end)
	end)

	it('validates field errors', function()
		assert_health({
			'- ERROR Expected `a` to be a `boolean`, but got a `number` value',
			'- ERROR Expected `b` to be a `number`, but got a `nil` value',
			'- WARNING Unknown field `a` in ``',
			'  - ADVICE:',
			'    - Did you mean: `b`',
			'- WARNING Unknown index `a` in ``',
		}, function()
			health.validate({}, { a = 0 }, function()
				return Nil
					/ Table({ a = Boolean })
					/ Table({ b = Number })
					/ Array(Nil)
					/ Nil
			end)
		end)
	end)

	it('displays complex type', function()
		assert_health({
			'- ERROR Expected `` to be a `boolean|number|string|function|((boolean)[])[]|(boolean|string)[]`, but got a `nil` value',
		}, function()
			health.validate({}, nil, function()
				return Boolean
					/ Number
					/ String
					/ Function
					/ Array(Array(Boolean))
					/ Array(Boolean / String)
			end)
		end)
	end)
end)

describe('Named', function()
	it('validates', function()
		assert_health({
			[[- OK `` validated (a `boolean` value)]],
		}, function()
			health.validate({}, true, function()
				return Named('MyType', Boolean)
			end)
		end)
	end)

	it('does not rename type in primitive error', function()
		assert_health({
			'- ERROR Expected `` to be a `boolean`, but got a `nil` value',
		}, function()
			health.validate({}, nil, function()
				return Named('MyType', Boolean)
			end)
		end)
	end)

	it('renames type in Union error', function()
		assert_health({
			'- ERROR Expected `` to be a `MyType|boolean`, but got a `nil` value',
		}, function()
			health.validate({}, nil, function()
				return Named('MyType', Boolean) / Boolean
			end)
		end)
	end)
end)

describe('check_executable()', function()
	it('prints ok', function()
		assert_health({
			string.format(
				'- OK `nvim` executable found (`%s`)',
				vim.fn.exepath('nvim')
			),
		}, function()
			health.check_executable('nvim')
		end)
	end)

	it('prints error', function()
		assert_health({
			'- ERROR `no-such-executable` not found in `$PATH` or not executable',
		}, function()
			health.check_executable('no-such-executable')
		end)
	end)
end)
