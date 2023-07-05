local osd = require('osd').new()
local mode = require('mode').new()
local utils = require('utils')

local M = 1024 * 1024
local G = 1024 * M

local CHOICES = {
	{ 'a', 125 * M, '125M' },
	{ 'b', 512 * M, '512M' },
	{ 'c', 1 * G, '1G' },
	{ 'd', 2 * G, '2G' },
	{ 'e', 4 * G, '4G' },
}

local visible = false
local name = 'demuxer-max-back-bytes'
local props = {}

local old_visible

local update

local function set_visible(action)
	visible = utils.reduce_bool(visible, action)
	return update()
end

local function update_property(name, value)
	props[name] = value
	return update()
end

function update()
	if old_visible ~= visible then
		old_visible = visible

		mp.unobserve_property(update)

		if visible then
			mp.observe_property(name, 'native', update_property)
			mp.observe_property('cache', 'native', update_property)
			osd.observe_fsc_properties(update_property)
			mode:add_key_bindings()
		else
			mp.unobserve_property(update_property)
			mode:remove_key_bindings()
			osd:remove()
		end
	end

	if not visible then
		return
	end

	osd:reset()
	osd:put_fsc(props, 2 + #CHOICES)
	osd:put('Cache:')

	osd:put('\\N')
	osd:put_marker(not props.cache)
	osd:put('n: none\\h')

	local current = props.cache and props[name]
	for _, choice in pairs(CHOICES) do
		local key, value, display = unpack(choice)

		osd:put('\\N')
		osd:put_marker(value == current)
		osd:put(key, ':\\h', display or value)
	end

	osd:update()
end
update = osd.update_wrap(update)

mode:map({
	ESC = function()
		set_visible('hide')
	end,
	n = function()
		set_visible('hide')
		mp.commandv('osd-msg-bar', 'set', 'cache', 'no')
	end,
})

for _, choice in ipairs(CHOICES) do
	local key, value = unpack(choice)
	mode:map(key, function()
		set_visible('hide')
		mp.commandv('osd-msg-bar', 'set', 'cache', 'yes')
		mp.commandv('osd-msg-bar', 'set', name, value)
	end)
end

utils.register_script_messages('osd-cache', {
	visibility = set_visible,
})

update()
