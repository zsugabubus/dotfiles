local utils = require('utils')

local PROPERTIES = {
	{ name = 'brightness', icon = 0xa },
	{ name = 'contrast', icon = 0x7 },
	{ name = 'gamma', icon = 0xa },
	{ name = 'saturation', icon = 0x8 },
	{ name = 'hue', icon = 0xb },
}

local presets
local props = {}

local function load_default_presets()
	presets = utils.read_lua_options('colors.lua') or {}
	table.insert(presets, 1, { name = 'none' })

	-- Normalize.
	for _, preset in ipairs(presets) do
		for _, p in ipairs(PROPERTIES) do
			preset[p.name] = preset[p.name] or 0
		end
	end
end

local function is_preset_active(preset)
	for _, p in ipairs(PROPERTIES) do
		if preset[p.name] ~= props[p.name] then
			return false
		end
	end
	return true
end

local function get_active_preset()
	for i, preset in ipairs(presets) do
		if is_preset_active(preset) then
			return i
		end
	end
end

local function apply_preset(preset)
	for _, p in ipairs(PROPERTIES) do
		mp.set_property_native(p.name, preset[p.name])
	end
	mp.osd_message(('Color preset: %s'):format(preset.name))
end

local function set_preset(action)
	if not presets then
		load_default_presets()
	end

	local i = get_active_preset()

	if action == 'prev' then
		if not i then
			return set_preset('last')
		else
			i = i - 1
			if i < 1 then
				return set_preset('last')
			end
		end
	elseif action == 'next' then
		if not i then
			return set_preset('first')
		else
			i = i + 1
			if i > #presets then
				return set_preset('first')
			end
		end
	elseif action == 'first' then
		i = 1
	elseif action == 'last' then
		i = #presets
	elseif tonumber(action) then
		i = tonumber(action)
	else
		for j, preset in ipairs(presets) do
			if preset.name == action then
				i = j
				break
			end
		end
	end

	local preset = presets[i]
	if preset then
		apply_preset(preset)
		return true
	end
end

local function update_property(name, value)
	props[name] = value
end

for _, p in ipairs(PROPERTIES) do
	mp.observe_property(p.name, 'native', update_property)
end

utils.register_script_messages('colors', {
	preset = set_preset,
})

load_default_presets()
