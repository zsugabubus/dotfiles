local PrimitiveSchema = {}
PrimitiveSchema.__index = PrimitiveSchema

local UnionSchema = {}
UnionSchema.__index = UnionSchema

local TableSchema = {}
TableSchema.__index = TableSchema

local ArraySchema = {}
ArraySchema.__index = ArraySchema

local NamedSchema = {}
NamedSchema.__index = NamedSchema

local CallbackSchema = {}
CallbackSchema.__index = CallbackSchema

local TypeError = {}
local UnionError = {}
local TableError = {}
local ArrayError = {}

local function validate_type(value, expected, schema)
	if type(value) ~= expected then
		return setmetatable({
			schema = schema,
			value = value,
		}, TypeError)
	end
end

local function validate_union(value, branch_schemas, schema)
	local branches = {}

	for _, branch_schema in ipairs(branch_schemas) do
		local err = branch_schema:validate(value)
		if not err then
			return
		end
		table.insert(branches, err)
	end

	return setmetatable({
		schema = schema,
		value = value,
		branches = branches,
	}, UnionError)
end

local function validate_table_fields(value, field_schemas, schema)
	local invalid_fields = {}
	local unknown_fields = {}

	for field_name, field_schema in pairs(field_schemas) do
		invalid_fields[field_name] = field_schema:validate(value[field_name])
	end

	for k in pairs(value) do
		if not field_schemas[k] then
			table.insert(unknown_fields, k)
		end
	end

	if #unknown_fields == 0 and next(invalid_fields) == nil then
		return
	end

	return setmetatable({
		schema = schema,
		value = value,
		invalid_fields = invalid_fields,
		unknown_fields = unknown_fields,
	}, TableError)
end

local function validate_array_fields(value, item_schema, schema)
	local invalid_indexes = {}
	local unknown_fields = {}

	for k, v in pairs(value) do
		if
			type(k) == 'number'
			and k >= 1
			and k <= #value
			and k == math.floor(k)
		then
			invalid_indexes[k] = item_schema:validate(v)
		else
			table.insert(unknown_fields, k)
		end
	end

	if #unknown_fields == 0 and next(invalid_indexes) == nil then
		return
	end

	return setmetatable({
		schema = schema,
		value = value,
		invalid_indexes = invalid_indexes,
		unknown_fields = unknown_fields,
	}, ArrayError)
end

local function make_primitive_schema(typename)
	return setmetatable({ typename = typename }, PrimitiveSchema)
end

local function make_union_schema(...)
	local t = {}

	for _, schema in ipairs({ ... }) do
		if getmetatable(schema) == UnionSchema then
			for _, x in ipairs(schema) do
				table.insert(t, x)
			end
		else
			table.insert(t, schema)
		end
	end

	return setmetatable(t, UnionSchema)
end

local function make_table_schema(fields)
	return setmetatable({ fields = fields }, TableSchema)
end

local function make_array_schema(item)
	return setmetatable({ item = item }, ArraySchema)
end

local function make_named_schema(name, inner)
	return setmetatable({ name = name, inner = inner }, NamedSchema)
end

local function make_callback_schema(callback, name)
	return setmetatable({
		name = name or 'custom',
		callback = callback,
	}, CallbackSchema)
end

PrimitiveSchema.__div = make_union_schema
TableSchema.__div = make_union_schema
ArraySchema.__div = make_union_schema
UnionSchema.__div = make_union_schema

function PrimitiveSchema:validate(value)
	return validate_type(value, self.typename, self)
end

function UnionSchema:validate(value)
	return validate_union(value, self, self)
end

function TableSchema:validate(value)
	return validate_type(value, 'table', self)
		or validate_table_fields(value, self.fields, self)
end

function ArraySchema:validate(value)
	return validate_type(value, 'table', self)
		or validate_array_fields(value, self.item, self)
end

function NamedSchema:validate(value)
	return self.inner:validate(value)
end

function CallbackSchema:validate(value)
	return self.callback(value)
end

local builtin_schemas = {
	Nil = make_primitive_schema('nil'),
	Boolean = make_primitive_schema('boolean'),
	Number = make_primitive_schema('number'),
	String = make_primitive_schema('string'),
	Function = make_primitive_schema('function'),
	Union = make_union_schema,
	Table = make_table_schema,
	Array = make_array_schema,
	Named = make_named_schema,
	Cb = make_callback_schema,
}

local function eval_schema(fn, schemas)
	setfenv(fn, schemas or builtin_schemas)
	return fn()
end

return {
	eval_schema = eval_schema,
	builtin_schemas = builtin_schemas,
	-- Schemas.
	PrimitiveSchema = PrimitiveSchema,
	UnionSchema = UnionSchema,
	TableSchema = TableSchema,
	ArraySchema = ArraySchema,
	NamedSchema = NamedSchema,
	CallbackSchema = CallbackSchema,
	-- Errors.
	TypeError = TypeError,
	UnionError = UnionError,
	TableError = TableError,
	ArrayError = ArrayError,
}
