local api = vim.api
local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn

local nr2char = fn.nr2char

local DEFAULT_UCDS = {
	'UnicodeData.txt',
	'NameAliases.txt',
}

local ns = api.nvim_create_namespace('vnicode')

local BUCKET_SIZE = 512
local ucd_cache = {}

local function flush_cache(ucd)
	local a = ucd_cache[ucd]
	if a then
		ucd_cache[ucd] = nil
		api.nvim_buf_delete(a.buf, { force = true })
	end
end

local function get_data_dir()
	return require('vnicode').config.data_dir
end

local function get_ucd_url(ucd)
	return string.format('https://www.unicode.org/Public/UCD/latest/ucd/%s', ucd)
end

local function get_ucd_path(ucd)
	return string.format('%s%s.xz', get_data_dir(), ucd)
end

local function get_installed_ucds()
	local t = {}
	for name in vim.fs.dir(get_data_dir()) do
		table.insert(t, string.match(name, '(.*)%.xz$'))
	end
	return t
end

local function install_ucd(ucd)
	local filename = get_ucd_path(ucd)
	local dirname = vim.fs.dirname(filename)
	fn.mkdir(dirname, 'p')
	cmd(
		string.format(
			'! curl %s | xz > %s',
			fn.shellescape(get_ucd_url(ucd)),
			fn.shellescape(filename)
		)
	)
	flush_cache(ucd)
end

local function get_codepoint_data(ucd, codepoint)
	local a = ucd_cache[ucd]
	if not a then
		local buf = fn.bufnr(get_ucd_path(ucd), true)
		fn.bufload(buf)

		a = { buf = buf }
		ucd_cache[ucd] = a

		for i, line in ipairs(api.nvim_buf_get_lines(buf, 0, -1, true)) do
			local m = string.match(line, '^[0-9A-F]+')
			if m then
				local cp = tonumber(m, 16)
				local n = math.floor(cp / BUCKET_SIZE)
				local b = a[n]
				if not b then
					b = {}
					a[n] = b
				end
				b[cp % BUCKET_SIZE] = i
			end
		end
	end

	local b = a[math.floor(codepoint / BUCKET_SIZE)]
	local row = b and b[codepoint % BUCKET_SIZE]
	if row then
		local line = api.nvim_buf_get_lines(a.buf, row - 1, row, true)[1]
		-- :VnicodeView modifies the buffer and prepends ";" to the line.
		line = string.sub(line, 2)
		return unpack(vim.split(line, ';'))
	end
end

local function iter_ucd_codepoints(ucd)
	return coroutine.wrap(function()
		get_codepoint_data(ucd, 0)

		for ai, b in pairs(assert(ucd_cache[ucd])) do
			if type(ai) == 'number' then
				for bi, row in pairs(b) do
					local codepoint = ai * BUCKET_SIZE + bi
					coroutine.yield(codepoint, row)
				end
			end
		end
	end)
end

local function get_unicode_data(codepoint)
	local found, character_name, general_category, _, _, decomposition =
		get_codepoint_data('UnicodeData.txt', codepoint)

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

local function get_alias_data(codepoint)
	local found, alias_name, alias_type =
		get_codepoint_data('NameAliases.txt', codepoint)

	if not found then
		return
	end

	return {
		alias_name = alias_name,
		alias_type = alias_type,
	}
end

local Printer = {}
Printer.__index = Printer

function Printer.new(cls)
	return setmetatable({
		_chunks = {},
	}, cls)
end

function Printer:put(text, hl_group)
	table.insert(self._chunks, { text, hl_group or 'Normal' })
end

function Printer:chunks()
	return self._chunks
end

function Printer:codepoint_graphics(codepoint, general_category)
	local group = string.sub(general_category, 1, 1)
	self:put('< ')
	if group == 'C' then
		if codepoint < 0x20 then
			self:put(string.format('^%c', string.byte('@') + codepoint), 'SpecialKey')
		else
			self:put(string.format('<%x>', codepoint), 'SpecialKey')
		end
	elseif group == 'M' then
		local DOTTED_CIRCLE = '\u{25cc}'
		self:put(DOTTED_CIRCLE .. nr2char(codepoint))
	else
		self:put(nr2char(codepoint))
	end
	self:put(' >')
end

function Printer:codepoint_dec(codepoint)
	self:put(tostring(codepoint), 'Number')
end

function Printer:codepoint_hex(codepoint)
	local width = math.ceil(math.log(codepoint) / math.log(16))
	local width = math.max(width, 4)
	self:put(string.format(string.format('U+%%0%dX', width), codepoint), 'Number')
end

function Printer:codepoint(codepoint)
	local unicode_data = get_unicode_data(codepoint)
	local alias_data = get_alias_data(codepoint)
	local character_name = unicode_data.character_name

	if alias_data and alias_data.alias_type == 'alternate' then
		character_name =
			string.format('%s/%s', alias_data.alias_name, character_name)
	elseif alias_data and alias_data.alias_type == 'abbreviation' then
		character_name =
			string.format('%s (%s)', alias_data.alias_name, character_name)
	elseif alias_data and alias_data.alias_type ~= '' then
		character_name = alias_data.alias_name
	end

	self:codepoint_graphics(codepoint, unicode_data.general_category)

	self:codepoint_dec(codepoint)
	self:put(', ')

	self:codepoint_hex(codepoint)
	self:put(', ')

	self:put(unicode_data.general_category)
	self:put('/')
	self:put(character_name, 'Identifier')

	if unicode_data.decomposition ~= '' then
		self:put(' = ')
		local i = 1
		for x in string.gmatch(unicode_data.decomposition, '[0-9A-F]+') do
			if i > 1 then
				self:put('+')
			end
			local codepoint = tonumber(x, 16)
			local unicode_data = get_unicode_data(codepoint)
			self:codepoint_graphics(codepoint, unicode_data.general_category)
			i = i + 1
		end
	end
end

function Printer:codepoints(codepoints)
	if #codepoints == 0 then
		self:put('(nothing to show)', 'NonText')
	end
	for i, codepoint in ipairs(codepoints) do
		if i > 1 then
			self:put('\n')
		end
		self:codepoint(codepoint)
	end
end

local function filter_completions(prefix, choices)
	return vim.tbl_filter(function(x)
		return vim.startswith(x, prefix)
	end, choices)
end

local function get_current_codepoints()
	local function is_normal_mode()
		return string.sub(api.nvim_get_mode().mode, 1, 1) == 'n'
	end

	local function get_cursor_text()
		local row, col = unpack(api.nvim_win_get_cursor(0))
		local line = api.nvim_buf_get_text(0, row - 1, col, row - 1, -1, {})[1]
		return fn.matchstr(line, '.')
	end

	local function get_visual_text()
		local value, mode = fn.getreg('', 1, true), fn.getregtype('')
		cmd.normal({ bang = true, args = { 'y' } })
		local text = fn.getreg('')
		fn.setreg('', value, mode)
		return text
	end

	local function get_current_text()
		if is_normal_mode() then
			return get_cursor_text()
		else
			return get_visual_text()
		end
	end

	return fn.str2list(get_current_text())
end

local function inspect()
	local printer = Printer:new()
	printer:codepoints(get_current_codepoints())
	api.nvim_echo(printer:chunks(), false, {})
end

local function view_cmd(opts)
	local ucd = opts.fargs[1] or 'NamesList.txt'
	local ucd_path = get_ucd_path(ucd)
	local new = fn.bufnr(ucd_path) < 0

	cmd.view(fn.fnameescape(ucd_path))

	if new then
		local buf = fn.bufnr(ucd_path)

		local bo = bo[buf]
		bo.undolevels = -1
		bo.swapfile = false
		bo.readonly = false
		bo.modifiable = true

		local NEW_LINE = 10

		for codepoint, row in iter_ucd_codepoints(ucd) do
			if codepoint ~= NEW_LINE then
				api.nvim_buf_set_text(buf, row - 1, 0, row - 1, 0, {
					fn.nr2char(codepoint) .. '\t',
				})
			end
		end

		bo.readonly = true
		bo.modified = false
		bo.modifiable = false
	end
end

local function view_complete(prefix)
	return table.concat(get_installed_ucds(), '\n')
end

local function install_cmd(opts)
	local ucds = #opts.fargs ~= 0 and opts.fargs or DEFAULT_UCDS
	for _, ucd in ipairs(ucds) do
		install_ucd(ucd)
	end
end

local function install_complete(prefix)
	return table.concat(
		fn.sort(vim.list_extend({ unpack(DEFAULT_UCDS) }, get_installed_ucds())),
		'\n'
	)
end

local function update_cmd()
	for _, ucd in ipairs(get_installed_ucds()) do
		install_ucd(ucd)
	end
end

local function read_vnicode_autocmd(opts)
	local buf = opts.buf
	local text = string.sub(opts.match, 11)
	local codepoints = fn.str2list(text)

	local printer = Printer:new()
	printer:codepoints(codepoints)

	local row, col = 0, 0
	for _, chunk in ipairs(printer:chunks()) do
		local text, hl_group = unpack(chunk)

		local start_row, start_col = row, col
		if text == '\n' then
			api.nvim_buf_set_text(buf, row, col, row, col, { '', '' })
			row = row + 1
			col = 0
		else
			api.nvim_buf_set_text(buf, row, col, row, col, { text })
			col = col + #text
		end

		api.nvim_buf_set_extmark(buf, ns, start_row, start_col, {
			hl_group = hl_group,
			end_row = row,
			end_col = col,
		})
	end

	local bo = bo[buf]
	bo.readonly = true
	bo.modeline = false
	bo.swapfile = false
end

return {
	get_data_dir = get_data_dir,
	get_installed_ucds = get_installed_ucds,
	inspect = inspect,
	install_cmd = install_cmd,
	install_complete = install_complete,
	read_vnicode_autocmd = read_vnicode_autocmd,
	update_cmd = update_cmd,
	view_cmd = view_cmd,
	view_complete = view_complete,
}
