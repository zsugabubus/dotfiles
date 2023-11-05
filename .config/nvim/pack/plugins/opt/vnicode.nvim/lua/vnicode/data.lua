local M = {}

local N = 512
local cache = {}

local function flush_cache(ucd)
	local a = cache[ucd]
	if a then
		cache[ucd] = nil
		vim.api.nvim_buf_delete(a.buf, { force = true })
	end
end

function M.get_data_dir()
	return require('vnicode').config.data_dir
end

function M.get_ucd_url(ucd)
	return string.format('https://www.unicode.org/Public/UCD/latest/ucd/%s', ucd)
end

function M.get_ucd_filename(ucd)
	return string.format('%s%s.xz', M.get_data_dir(), ucd)
end

function M.get_default_ucds(ucd)
	return {
		'UnicodeData.txt',
		'NameAliases.txt',
	}
end

function M.get_installed_ucds(ucd)
	local result = {}
	for name in vim.fs.dir(M.get_data_dir()) do
		result[#result + 1] = string.match(name, '(.*)%.xz$')
	end
	return result
end

function M.install(ucd)
	local filename = M.get_ucd_filename(ucd)
	local dirname = vim.fs.dirname(filename)
	vim.fn.mkdir(dirname, 'p')
	vim.cmd(
		string.format(
			'! curl %s | xz > %s',
			vim.fn.shellescape(M.get_ucd_url(ucd)),
			vim.fn.shellescape(filename)
		)
	)
	flush_cache(ucd)
end

function M.get(ucd, codepoint)
	local a = cache[ucd]
	if not a then
		local buf = vim.fn.bufnr(M.get_ucd_filename(ucd), true)
		vim.fn.bufload(buf)

		a = { buf = buf }
		cache[ucd] = a

		for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, true)) do
			local m = string.match(line, '^[0-9A-F]+')
			if m then
				local cp = tonumber(m, 16)
				local n = math.floor(cp / N)
				local b = a[n]
				if not b then
					b = {}
					a[n] = b
				end
				b[cp % N] = i
			end
		end
	end

	local b = a[math.floor(codepoint / N)]
	local row = b and b[codepoint % N]
	if row then
		local line = vim.api.nvim_buf_get_lines(a.buf, row - 1, row, true)[1]
		return unpack(vim.split(line, ';'))
	end
end

function M.ucd_codepoints(ucd)
	local co = coroutine.create(function()
		M.get(ucd, 0)
		for ai, b in pairs(assert(cache[ucd])) do
			if type(ai) == 'number' then
				for bi, row in pairs(b) do
					local ch = ai * N + bi
					coroutine.yield(ch, row)
				end
			end
		end
	end)

	return function()
		local ok, ch, row = coroutine.resume(co)
		if ok then
			return ch, row
		end
	end
end

function M.get_unicode_data(codepoint)
	local found, character_name, general_category, _, _, decomposition =
		M.get('UnicodeData.txt', codepoint)

	if not found then
		return {
			character_name = 'NO NAME',
			general_category = 'Cn',
			decomposition = '',
		}
	end

	return {
		character_name = character_name,
		general_category = general_category,
		decomposition = decomposition,
	}
end

function M.get_alias_data(codepoint)
	local found, alias_name, alias_type = M.get('NameAliases.txt', codepoint)

	if not found then
		return
	end

	return {
		alias_name = alias_name,
		alias_type = alias_type,
	}
end

return M
