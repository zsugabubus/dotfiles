local lpeg = vim.lpeg

local Cc = lpeg.Cc
local Cg = lpeg.Cg
local Cs = lpeg.Cs
local Ct = lpeg.Ct
local P = lpeg.P
local R = lpeg.R
local V = lpeg.V

local alpha = R('az', 'AZ')
local colon = P(':')
local digit = R('09')
local dollar = P('$')
local escape = (P('\\') / '') * P(1)
local l_brace = P('{')
local r_brace = P('}')
local underscore = P('_')

local node = function(x, type)
	return Ct(x * Cg(Cc(type), 'type'))
end
local placeholder = function(id, type)
	return node(
		dollar * (id + (l_brace * id * (V('default') ^ -1) * r_brace)),
		type
	)
end
local any = function(text_till)
	local text = node(Cg(Cs((escape + (P(1) - text_till)) ^ 1), 'body'), 'text')
	return Ct((text + V('tabstop') + V('variable')) ^ 0)
end

local snippet = P({
	'snippet',
	snippet = any(dollar) * -1,
	tabstop = placeholder(V('number'), 'tabstop'),
	variable = placeholder(V('name'), 'variable'),
	number = Cg((digit ^ 1) / tonumber, 'number'),
	name = Cg((underscore + alpha) * (underscore + alpha + digit) ^ 0, 'name'),
	default = colon * Cg(any(dollar + r_brace), 'default'),
})

return {
	parse = function(input)
		return snippet:match(input)
	end,
}
