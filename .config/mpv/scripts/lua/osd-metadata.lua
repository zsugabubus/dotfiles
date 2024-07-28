local osd = require('osd').new()
local utils = require('utils')

local visible = false
local props = {}

local old_visible

local update

local function set_visible(action)
	visible = utils.reduce_bool(visible, action)
	update()
end

local function update_property(name, value)
	-- Ignore not yet loaded properties.
	if value == nil then
		return
	end

	props[name] = value

	if name == 'metadata' then
		local list = {}
		for k, v in pairs(value) do
			table.insert(list, { k, v })
		end
		table.sort(list, function(x, y)
			return x[1] < y[1]
		end)
		props['metadata/list'] = list
	end

	update()
end

function update()
	if old_visible ~= visible then
		old_visible = visible

		mp.unobserve_property(update_property)

		if visible then
			mp.observe_property('metadata', 'native', update_property)
			osd.observe_fsc_properties(update_property)
		else
			osd:remove()
		end

		return
	end

	if not visible then
		return
	end

	osd:clear()
	osd:an(9)
	osd:put_fsc(props, #props['metadata/list'], 0.5)
	osd:an(9)
	osd:bord(2)

	for _, kv in pairs(props['metadata/list']) do
		local k, v = unpack(kv)
		osd:bold(true)
		osd:str(k)
		osd:bold(false)
		osd:put(': ')
		osd:strnl(v)
		osd:N()
	end

	if #props['metadata/list'] == 0 then
		osd:put('(no metadata)')
	end

	osd:update()
end
update = osd.update_wrap(update)

utils.register_script_messages('osd-metadata', {
	visibility = set_visible,
})

update()
