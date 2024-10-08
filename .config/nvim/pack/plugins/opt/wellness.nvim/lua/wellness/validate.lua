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

local function stringify_schema(schema)
	local ty = getmetatable(schema)
	if ty == S.PrimitiveSchema then
		return schema.typename
	elseif ty == S.UnionSchema then
		local t = {}

		for _, branch_schema in ipairs(schema) do
			table.insert(t, stringify_schema(branch_schema))
		end

		return table.concat(t, '|')
	elseif ty == S.TableSchema then
		return 'table'
	elseif ty == S.ArraySchema then
		return string.format('(%s)[]', stringify_schema(schema.item))
	elseif ty == S.NamedSchema then
		return schema.name
	elseif ty == S.CallbackSchema then
		return schema.name
	else
		error('unknown schema')
	end
end

local function display_schema(schema)
	return string.format('`%s`', stringify_schema(schema))
end

local function report_error(err, path)
	local ty = getmetatable(err)
	if ty == S.TypeError then
		health.error(
			string.format(
				'Expected %s to be a %s, but got a %s value',
				display_path(path),
				display_type(err.schema.typename or 'table'),
				display_type(type(err.value))
			)
		)
	elseif ty == S.UnionError then
		local type_errors_only = true

		for _, branch in ipairs(err.branches) do
			if getmetatable(branch) ~= S.TypeError then
				type_errors_only = false
				break
			end
		end

		if type_errors_only then
			health.error(
				string.format(
					'Expected %s to be a %s, but got a %s value',
					display_path(path),
					display_schema(err.schema),
					display_type(type(err.value))
				)
			)
			return
		end

		for _, branch in ipairs(err.branches) do
			if getmetatable(branch) ~= S.TypeError then
				report_error(branch, path)
			end
		end
	elseif ty == S.TableError then
		for k, v in vim.spairs(err.invalid_fields) do
			table.insert(path, k)
			report_error(v, path)
			table.remove(path)
		end

		if #err.unknown_fields > 0 then
			health.warn(
				string.format(
					'Unknown %s %s in %s',
					#err.unknown_fields == 1 and 'field' or 'fields',
					display_keys(err.unknown_fields),
					display_path(path)
				),
				string.format(
					'Did you mean: %s',
					display_keys(vim.tbl_keys(err.schema.fields))
				)
			)
		end
	elseif ty == S.ArrayError then
		for k, v in vim.spairs(err.invalid_indexes) do
			table.insert(path, k)
			report_error(v, path)
			table.remove(path)
		end

		if #err.unknown_fields > 0 then
			health.warn(
				string.format(
					'Unknown %s %s in %s',
					#err.unknown_fields == 1 and 'index' or 'indexes',
					display_keys(err.unknown_fields),
					display_path(path)
				)
			)
		end
	else
		error('unknown error')
	end
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

	report_error(err, path)
end

return validate
