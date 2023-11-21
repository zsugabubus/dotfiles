local osd = require('osd').new()
local mode = require('mode').new()
local utils = require('utils')

local PROPERTIES = {
	{ name = 'brightness', short_name = 'b', icon = 0xa },
	{ name = 'contrast', short_name = 'c', icon = 0x7 },
	{ name = 'gamma', short_name = 'g', icon = 0xa },
	{ name = 'saturation', short_name = 's', icon = 0x8 },
	{ name = 'hue', short_name = 'h', icon = 0xb },
}

local visible = false
local cursor_id = 1
local presets
local props = {}

local old_visible

local update

local function set_visible(action)
	visible = utils.reduce_bool(visible, action)
	update()
end

local function load_default_presets()
	presets = utils.do_script_opt('color-presets.lua') or {}
	table.insert(presets, 1, { name = 'none' })

	-- Normalize.
	for _, preset in ipairs(presets) do
		for _, p in ipairs(PROPERTIES) do
			preset[p.name] = preset[p.name] or preset[p.short_name] or 0
		end
	end

	update()
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
	mp.osd_message(string.format('Color preset: %s', preset.name))
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

local function set_cursor(action)
	if action == 'up' then
		cursor_id = cursor_id - 1
		if cursor_id < 1 then
			return set_cursor('last')
		end
	elseif action == 'down' then
		cursor_id = cursor_id + 1
		if cursor_id > #PROPERTIES then
			return set_cursor('first')
		end
	elseif action == 'first' then
		cursor_id = 1
	elseif action == 'last' then
		cursor_id = #PROPERTIES
	end

	update()
end

local function set_value(value, how)
	local name = PROPERTIES[cursor_id].name
	value = value + (how ~= 'absolute' and props[name] or 0)
	mp.set_property_native(name, value)
end

local function update_property(name, value)
	props[name] = value
	update()
end

for _, p in ipairs(PROPERTIES) do
	mp.observe_property(p.name, 'native', update_property)
end

function update()
	if old_visible ~= visible then
		old_visible = visible

		if visible then
			mode:add_key_bindings()
		else
			mode:remove_key_bindings()
			osd:remove()
		end

		if visible then
			load_default_presets()
		end
	end

	if not visible then
		return
	end

	osd:reset()
	osd:put('\\h\n{\\q2}')

	for i, p in ipairs(PROPERTIES) do
		local current = i == cursor_id

		osd:put_cursor(current)
		osd:put(
			-- Bold must be turned off otherwise font gets messed up after the
			-- symbol.
			'{\\b0\\fnmpv-osd-symbols}\238\128',
			string.char(128 + p.icon),
			'\\h'
		)
		osd:put(
			current and '{\\b1}' or '',
			string.upper(string.sub(p.name, 1, 1)),
			string.sub(p.name, 2),
			': ',
			props[p.name]
		)
		osd:put_rcursor(current)
		osd:put('\\N')
	end

	local current_preset = get_active_preset()

	osd:put('\\h\n{\\q2\\fscx80\\fscy80}', 'Available Presets:')
	for i, preset in ipairs(presets) do
		osd:put('\\N')
		osd:put_marker(i == current_preset)
		osd:put(i - 1, ': ', preset.name)
	end

	osd:update()
end
update = osd.update_wrap(update)

mode:map({
	UP = function()
		set_cursor('up')
	end,
	DOWN = function()
		set_cursor('down')
	end,
	HOME = function()
		set_cursor('first')
	end,
	END = function()
		set_cursor('last')
	end,
	LEFT = function()
		set_value(-1)
	end,
	RIGHT = function()
		set_value(1)
	end,
	['-'] = 'LEFT',
	['+'] = 'RIGHT',
	['Shift+LEFT'] = function()
		set_value(-5)
	end,
	['Shift+RIGHT'] = function()
		set_value(5)
	end,
	r = function()
		set_value(0, 'absolute')
	end,
	R = function()
		for _, p in ipairs(PROPERTIES) do
			mp.set_property_native(p.name, 0)
		end
	end,
	TAB = function()
		set_preset('next')
	end,
	['Shift+TAB'] = function()
		set_preset('prev')
	end,
	['0..9'] = function(i)
		if set_preset(i + 1) then
			set_visible('hide')
		end
	end,
	F5 = function()
		load_default_presets()
	end,
	ESC = function()
		set_visible('hide')
	end,
})

utils.register_script_messages('osd-colors', {
	visibility = set_visible,
	preset = set_preset,
})

update()
