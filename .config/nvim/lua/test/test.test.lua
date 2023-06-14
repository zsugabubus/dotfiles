eq(0, 1)

function test_pass()
	eq(0, 0)
end

function test_fail()
	eq(0, 1)
end

function test_pass_then_fail()
	eq(0, 0)
	eq(0, 1)
end

function test_fail_then_pass()
	eq(0, 1)
	eq(0, 0)
end

function test_error()
	error('test')
end

function test_empty() end

function test_mat()
	function test_ros()
		function test_ka()
			eq()
		end
	end
end

test('test_parameters', {
	{ nil, nil },
	{ 1, nil },
	{ nil, 1 },
}, function(a, b)
	eq(a, b)
end)

test(
	'test_parameter_name_specifiers %s %s %s %3 %2 %1 (%0)',
	{ { 'a', 'b' } },
	function()
		eq()
	end
)

test('test_parameter_name_single_line', { { { nil, 2, 3 } } }, function()
	eq()
end)

test('test_no_parameters', {}, function() end)
test('test_parameters_with_empty', { {} }, function() end)

test(
	'test_call',
	setmetatable({}, {
		__call = function()
			eq()
		end,
	})
)

function describe_skip()
	function it_skips()
		skip()
		error('unreachable')
	end

	skip(false)

	function test_some_test()
		eq()
	end

	skip(false) -- TEST: Should see fail message after eq().

	function test_skip2()
		skip(true) -- TEST: Above message should not affect this.
		error('unreachable')
	end
end

a = b

test('deep', function()
	eq({ { a = { 1 } } }, { { a = { 1 } } })
end)

error('bye')
