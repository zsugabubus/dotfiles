local osd = require('osd').new()
local mode = require('mode').new()
local utils = require('utils')

local MiB = 1024 * 1024
local GiB = 1024 * MiB

local CHOICES = {
	{ 'a', 125 * MiB, '125M' },
	{ 'b', 512 * MiB, '512M' },
	{ 'c', 1 * GiB, '1G' },
	{ 'd', 2 * GiB, '2G' },
	{ 'e', 4 * GiB, '4G' },
}

local modal
local update
local old_visible = false
local name = 'demuxer-max-back-bytes'
local props = {}

local function update_property(name, value)
	props[name] = value
	update()
end

function update()
	local visible = modal:is_visible()

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

	osd:clear()
	osd:put_fsc(props, 2 + #CHOICES)
	osd:put('Cache:')

	osd:N()
	osd:put_marker(not props.cache)
	osd:put('n: none')

	local current = props.cache and props[name]
	for _, choice in pairs(CHOICES) do
		local key, value, display = unpack(choice)

		osd:N()
		osd:put_marker(value == current)
		osd:put(key, ':')
		osd:h()
		osd:str(display or value)
	end

	osd:update()
end
update = osd.update_wrap(update)

modal = require('modal').new(update)

mode:map({
	ESC = function()
		modal:hide()
	end,
	n = function()
		modal:hide()
		mp.commandv('osd-msg-bar', 'set', 'cache', 'no')
	end,
})

for _, choice in ipairs(CHOICES) do
	local key, value = unpack(choice)
	mode:map(key, function()
		modal:hide()
		mp.commandv('osd-msg-bar', 'set', 'cache', 'yes')
		mp.commandv('osd-msg-bar', 'set', name, value)
	end)
end

utils.register_script_messages('osd-cache', {
	visibility = modal.set_visibility,
})
