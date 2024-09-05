local S = require('schema')

local health = vim.health

local function is_ident(x)
	return type(x) == 'string' and string.find(x, '^[a-zA-Z_][0-9a-zA-Z_]*$')
end

local function key_tostring(x)
	if is_ident(x) or type(x) == 'number' then
		return x
	elseif type(x) == 'string' then
		return vim.inspect(x)
	else
		return string.format('<%s>', type(x))
	end
end

local function display_type(typename)
	return string.format('`%s`', typename)
end

local function display_path(path)
	local s = ''

	for _, key in ipairs(path) do
		if is_ident(key) then
			s = s .. ((s ~= '' and '.' or '') .. key)
		else
			s = s .. '[' .. key_tostring(key) .. ']'
		end
	end

	return string.format('`%s`', s)
end

local function display_keys(keys)
	local t = {}

	for _, key in ipairs(keys) do
		table.insert(t, string.format('`%s`', key_tostring(key)))
	end

	table.sort(t)

	return table.concat(t, ', ')
end

local schema_tostring
local SCHEMA_TOSTRING_IMPL = {
	[S.PrimitiveSchema] = function(self)
		return self.typename
	end,
	[S.UnionSchema] = function(self)
		local t = {}

		for _, branch_schema in ipairs(self) do
			table.insert(t, schema_tostring(branch_schema))
		end

		return table.concat(t, '|')
	end,
	[S.TableSchema] = function(self)
		return 'table'
	end,
	[S.ArraySchema] = function(self)
		return string.format('(%s)[]', schema_tostring(self.item))
	end,
	[S.NamedSchema] = function(self)
		return self.name
	end,
	[S.CallbackSchema] = function(self)
		return self.name
	end,
}
function schema_tostring(schema)
	return SCHEMA_TOSTRING_IMPL[getmetatable(schema)](schema)
end

local function display_schema(schema)
	return string.format('`%s`', schema_tostring(schema))
end

local error_print
local ERROR_PRINT_IMPL = {
	[S.TypeError] = function(self, path)
		health.error(
			string.format(
				'Expected %s to be a %s, but got a %s value',
				display_path(path),
				display_type(self.schema.typename or 'table'),
				display_type(type(self.value))
			)
		)
	end,
	[S.UnionError] = function(self, path)
		local type_errors_only = true

		for _, branch_error in ipairs(self.branches) do
			if getmetatable(branch_error) ~= S.TypeError then
				type_errors_only = false
				break
			end
		end

		if type_errors_only then
			health.error(
				string.format(
					'Expected %s to be a %s, but got a %s value',
					display_path(path),
					display_schema(self.schema),
					display_type(type(self.value))
				)
			)
			return
		end

		for _, branch_error in ipairs(self.branches) do
			if getmetatable(branch_error) ~= S.TypeError then
				error_print(branch_error, path)
			end
		end
	end,
	[S.TableError] = function(self, path)
		for k, v in vim.spairs(self.invalid_fields) do
			table.insert(path, k)
			error_print(v, path)
			table.remove(path)
		end

		if #self.unknown_fields > 0 then
			health.warn(
				string.format(
					'Unknown %s %s in %s',
					#self.unknown_fields == 1 and 'field' or 'fields',
					display_keys(self.unknown_fields),
					display_path(path)
				),
				string.format(
					'Did you mean: %s',
					display_keys(vim.tbl_keys(self.schema.fields))
				)
			)
		end
	end,
	[S.ArrayError] = function(self, path)
		for k, v in vim.spairs(self.invalid_indexes) do
			table.insert(path, k)
			error_print(v, path)
			table.remove(path)
		end

		if #self.unknown_fields > 0 then
			health.warn(
				string.format(
					'Unknown %s %s in %s',
					#self.unknown_fields == 1 and 'index' or 'indexes',
					display_keys(self.unknown_fields),
					display_path(path)
				)
			)
		end
	end,
}
function error_print(err, path)
	return ERROR_PRINT_IMPL[getmetatable(err)](err, path)
end

local function validate(path, value, schema)
	local schema = S.eval_schema(schema)
	local err = schema:validate(value)

	if not err then
		health.ok(
			string.format(
				'%s validated (a %s value)',
				display_path(path),
				display_type(type(value))
			)
		)
		return
	end

	error_print(err, path)
end

return validate
