local vim = create_vim({ isolate = false })

describe('parse()', function()
	local function parse(...)
		return vim:lua(function(...)
			return require('snippets.textmate').parse(...)
		end, ...)
	end

	it('works', function()
		local function test_case(output, input)
			return assert.same(output, parse(input))
		end

		test_case({}, '')
		test_case({ { type = 'text', body = 'x' } }, 'x')
		test_case({ { type = 'text', body = 'x\nx' } }, 'x\nx')
		test_case({ { type = 'text', body = '{$}' } }, '{\\$}')
		test_case({ { type = 'text', body = 'á' } }, 'á')

		test_case(nil, '$')
		test_case({ { type = 'variable', name = 'x' } }, '$x')
		test_case({ { type = 'variable', name = 'X' } }, '$X')
		test_case({ { type = 'variable', name = '_' } }, '$_')
		test_case({ { type = 'variable', name = '_AZ_az_09' } }, '$_AZ_az_09')
		test_case(nil, '${}')
		test_case({ { type = 'variable', name = 'x' } }, '${x}')
		test_case({ { type = 'variable', name = 'x', default = {} } }, '${x:}')

		test_case({ { type = 'tabstop', number = 0 } }, '$0')
		test_case({ { type = 'tabstop', number = 0 } }, '$000')
		test_case({ { type = 'tabstop', number = 999 } }, '$999')
		test_case({ { type = 'tabstop', number = 999 } }, '${999}')
		test_case({ { type = 'tabstop', number = 0, default = {} } }, '${0:}')

		test_case({
			{ type = 'text', body = 'a' },
			{ type = 'tabstop', number = 0 },
			{ type = 'variable', name = 'b' },
			{ type = 'text', body = 'c' },
		}, 'a$0${b}c')

		test_case({
			{
				type = 'tabstop',
				number = 1,
				default = {
					{
						type = 'variable',
						name = 'a',
						default = {
							{
								type = 'tabstop',
								number = 2,
								default = {
									{
										type = 'variable',
										name = 'b',
										default = { { type = 'text', body = '}' } },
									},
								},
							},
						},
					},
				},
			},
		}, '${1:${a:${2:${b:\\}}}}}')
	end)
end)
