local Mode = {}

local COMPLEX = {complex=true}
local HELP_KEY_BINDINGS = {'?', 'F1'}

local function add_key_binding(self, key, fn)
	while type(fn) ~= 'function' do
		if not fn then
			-- May have help text only.
			return
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
	end, COMPLEX)
end

local function remove_key_binding(self, key)
	mp.remove_key_binding('mode/' .. key)
end

local function update_osd_data(self)
	local help = {}

	for key, fn in pairs(self.key_bindings) do
		local text = nil
		while type(fn) ~= 'function' do
			if type(fn) == 'table' then
				text, fn = unpack(fn)
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
		'{\\r\\a2\\bord2\\alpha&H20\\q1\\fscx50\\fscy50}',
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

	self.osd.data = table.concat(data)
end

local function update_osd(self)
	if self.added and self.show_help then
		if not self.osd then
			self.osd = mp.create_osd_overlay('ass-events')
			self.osd.z = 1
			update_osd_data(self, o)
		end

		self.osd:update()
	elseif self.osd then
		self.osd:remove()
	end
end

function Mode:toggle()
	self.show_help = not self.show_help
	update_osd(self)
end

function Mode:add_key_bindings()
	local self_toggle = function()
		self:toggle()
	end
	for _, key in ipairs(HELP_KEY_BINDINGS) do
		add_key_binding(self, key, self_toggle)
	end

	for key, fn in pairs(self.key_bindings) do
		add_key_binding(self, key, fn)
	end

	self.added = true
	update_osd(self)
end

function Mode:remove_key_bindings()
	for _, key in ipairs(HELP_KEY_BINDINGS) do
		remove_key_binding(self, key)
	end
	for key, _ in pairs(self.key_bindings) do
		remove_key_binding(self, key)
	end

	self.added = false
	update_osd(self)
end

Mode.__index = Mode

return function(key_bindings)
	local o = {
		key_bindings=key_bindings,
		show_help=(mp.get_opt('mode-help') == 'on')
	}
	setmetatable(o, Mode)
	return o
end
