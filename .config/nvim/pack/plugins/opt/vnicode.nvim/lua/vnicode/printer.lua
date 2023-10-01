local nr2char = vim.fn.nr2char

local M = {}
M.__index = M

function M.new(cls)
	return setmetatable({
		_chunks = {},
	}, cls)
end

function M:print(text, hl_group)
	table.insert(self._chunks, { text, hl_group or 'Normal' })
end

function M:chunks()
	return self._chunks
end

function M:empty()
	self:print('(nothing to show)', 'NonText')
end

function M:codepoint_graphics(codepoint, general_category)
	local group = string.sub(general_category, 1, 1)
	self:print('< ')
	if group == 'C' then
		if codepoint < 0x20 then
			self:print(
				string.format('^%c', string.byte('@') + codepoint),
				'SpecialKey'
			)
		else
			self:print(string.format('<%x>', codepoint), 'SpecialKey')
		end
	elseif group == 'M' then
		local DOTTED_CIRCLE = '\u{25cc}'
		self:print(DOTTED_CIRCLE .. nr2char(codepoint))
	else
		self:print(nr2char(codepoint))
	end
	self:print(' >')
end

function M:codepoint_dec(codepoint)
	self:print(tostring(codepoint), 'Number')
end

function M:codepoint_hex(codepoint)
	local width = math.ceil(math.log(codepoint) / math.log(16))
	local width = math.max(width, 4)
	self:print(
		string.format(string.format('U+%%0%dX', width), codepoint),
		'Number'
	)
end

function M:codepoint_utf8(codepoint)
	local s = nr2char(codepoint)
	for i = 1, #s do
		if i > 1 then
			self:print(' ')
		end
		self:print(string.format('0x%02X', string.byte(s, i)), 'Number')
	end
end

function M:codepoint(codepoint, show_utf8)
	local data = require('vnicode.data')

	local unicode_data = data.get_unicode_data(codepoint)
	local alias_data = data.get_alias_data(codepoint)
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
	self:print(', ')

	self:codepoint_hex(codepoint)
	self:print(', ')

	if show_utf8 then
		self:codepoint_utf8(codepoint)
		self:print(', ')
	end

	self:print(unicode_data.general_category)
	self:print('/')
	self:print(character_name, 'Identifier')

	if unicode_data.decomposition ~= '' then
		self:print(' = ')
		local i = 1
		for x in string.gmatch(unicode_data.decomposition, '[0-9A-F]+') do
			if i > 1 then
				self:print('+')
			end
			local codepoint = tonumber(x, 16)
			local unicode_data = data.get_unicode_data(codepoint)
			self:codepoint_graphics(codepoint, unicode_data.general_category)
			i = i + 1
		end
	end
end

function M:codepoints(codepoints, show_utf8)
	if #codepoints == 0 then
		self:empty()
	end
	for i, codepoint in ipairs(codepoints) do
		if i > 1 then
			self:print('\n')
		end
		self:codepoint(codepoint, show_utf8)
	end
end

return M
