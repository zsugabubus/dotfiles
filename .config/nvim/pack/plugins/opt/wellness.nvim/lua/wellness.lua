local health = vim.health

local function validate(...)
	require('wellness.validate')(...)
end

local function validate_path(path, schema)
	local value = loadstring('return ' .. path)()
	validate(vim.split(path, '%.'), value, schema)
end

local function check_executable(name)
	if vim.fn.executable(name) == 1 then
		health.ok(
			string.format('`%s` executable found (`%s`)', name, vim.fn.exepath(name))
		)
	else
		health.error(
			string.format('`%s` not found in `$PATH` or not executable', name)
		)
	end
end

return {
	validate = validate,
	validate_path = validate_path,
	check_executable = check_executable,
}
