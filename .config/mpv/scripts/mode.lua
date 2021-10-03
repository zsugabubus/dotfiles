local NBSP = '\194\160'
local Mode = {}

function Mode:add_key_bindings()
	for key, fn in pairs(self.key_bindings) do
		while type(fn) ~= 'function' do
			if not fn then
				-- May have help text only.
				goto no_binding
			elseif type(fn) == 'table' then
				fn = fn[2]
			else
				fn = self.key_bindings[fn]
			end
		end

		mp.add_forced_key_binding(key, 'mode/' .. key, function(e)
			if e.event == 'down' or e.event == 'repeat' then
				fn()
			end
		end, {complex=true})

		::no_binding::
	end
end

function Mode:remove_key_bindings()
	for key, _ in pairs(self.key_bindings) do
		mp.remove_key_binding('mode/' .. key)
	end
end

function Mode:get_ass_help()
	if self.cached_ass_help then
		return self.cached_ass_help
	end

	local help = {}

	for key, fn in pairs(self.key_bindings) do
		local text = nil
		while type(fn) ~= 'function' do
			if type(fn) == 'table' then
				text, fn = table.unpack(fn)
				if text then
					break
				end
			else
				fn = self.key_bindings[fn]
			end
		end

		if text then
			if not help[text] then
				help[text] = {}
			end
			help[text][#help[text] + 1] = key
		end
	end

	-- Order of help entries.
	local order = {}

	for k in pairs(help) do
		order[#order + 1] = k
	end

	table.sort(order)

	local data = {
		'\n{\\r\\a2\\bord2\\alpha&H50\\fscx50\\fscy50}',
	}

	for _, text in ipairs(order) do
		if 1 < #data then
			data[#data + 1] = ' | '
		end

		keys = help[text]
		table.sort(keys)
		for i, key in ipairs(keys) do
			if 1 < i then
				data[#data + 1] = ','
			end
			data[#data + 1] = '{\\b1}'
			data[#data + 1] = key:gsub('{', '\\{')
			data[#data + 1] = '{\\b0}'
		end

		data[#data + 1] = ':'
		data[#data + 1] = text
	end

	data[#data + 1] = '\\N'

	self.cached_ass_help = table.concat(data)
	return self.cached_ass_help
end

Mode.__index = Mode

return function(key_bindings)
	local o = {
		key_bindings=key_bindings,
	}
	setmetatable(o, Mode)
	return o
end
