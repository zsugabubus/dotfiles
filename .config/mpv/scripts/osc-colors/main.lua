local NBSP = '\194\160'

local OPTIONS = {
	{option='brightness', icon=0xa},
	{option='contrast',   icon=0x7},
	{option='gamma',      icon=0xa},
	{option='saturation', icon=0x8},
	{option='hue',        icon=0xb},
}

local utils = require('mp.utils')
local script_opts = mp.command_native({'expand-path', '~~/script-opts'})
PRESETS = dofile(script_opts .. '/color-presets.lua') or {
	{name='(none)'},
	{name='tv', b=2, c=3, g=3, s=3 },
}

local mode = dofile(mp.get_script_directory() .. '/mode.lua')
local osd = mp.create_osd_overlay('ass-events')
local visible = false
local last_changed = OPTIONS[1].option

local ignore_once, file_loaded = true, false
mp.register_event('end-file', function()
	file_loaded = false
	visible = false
	update_menu()
end)
mp.register_event('playback-restart', function() file_loaded = true end)

local timeout = mp.add_timeout(mp.get_property_number('osd-duration') / 1000, function()
	visible = false
	update_menu()
end)
timeout:kill()

function select_abs(i)
	local preset = PRESETS[i]
	for _,x in ipairs(OPTIONS) do
		mp.set_property_number(x.option, preset[x.option:sub(1, 1)] or 0)
	end
	mp.osd_message(('Color preset: %s'):format(preset.name))
end

function select_rel(n)
	local i = 1
	for k,preset in pairs(PRESETS) do
		local match = true
		for _,x in ipairs(OPTIONS) do
			match = match and (preset[x.option:sub(1, 1)] or 0) == mp.get_property_number(x.option)
		end
		if match then
			i = k + n
			break
		end
	end

	select_abs((i - 1 + #PRESETS) % #PRESETS + 1)
end

local keys = {
	q=function()
		visible = false
		update_menu()
	end,
	ESC='q',
	n=function() select_rel(1) end,
	p=function() select_rel(-1) end,
	r=function() mp.commandv('osd-bar', 'set', last_changed, 0) end,
	['-']=function() mp.commandv('osd-bar', 'add', last_changed, -1) end,
	['+']=function() mp.commandv('osd-bar', 'add', last_changed,  1) end,
	j='-',
	k='+',
	x='-',
	a='+',
}
for _,x in ipairs(OPTIONS) do
	keys[x.option:sub(1, 1)] =
		function()
			last_changed = x.option
			mp.commandv('osd-bar', 'add', x.option,  1)
		end
	keys[x.option:sub(1, 1):upper()] =
		function()
			last_changed = x.option
			mp.commandv('osd-bar', 'add', x.option, -1)
		end
end
for i=0,9 do
	keys[string.char(string.byte('0') + i)] =
		function()
			ignore_once = true
			select_abs(i + 1)
			visible = false
			update_menu()
		end
end

mp.register_script_message('next-preset', keys.n)
mp.register_script_message('prev-preset', keys.p)

function update()
	mp.unregister_idle(_update)
	mp.register_idle(_update)
end
function _update()
	mp.unregister_idle(_update)

	if ignore_once or not file_loaded then
		ignore_once = false
		return
	end

	osd.data = {NBSP .. '\n'}

	for _,x in ipairs(OPTIONS) do
		table.insert(osd.data, table.concat{
			"{\\fnmpv-osd-symbols}\238\128", string.char(128 + x.icon), ' ',
			x.option:sub(1, 1):upper(), x.option:sub(2), ': ',
			mp.get_property_number(x.option), '\\N'
		})
	end

	if visible then
		table.insert(osd.data, '{\\fscx75\\fscy75}')
		for i,preset in ipairs(PRESETS) do
			table.insert(osd.data, ('\\N%d: %s'):format(i - 1, preset.name))
		end
	end

	osd.data = table.concat(osd.data):gsub(' ', NBSP)

	osd:update()
	if not visible then
		timeout:kill()
		timeout:resume()
	end
end

for _,x in ipairs(OPTIONS) do
	mp.observe_property(x.option, nil, function()
		last_changed = x.option
		update()
	end)
end

function update_menu()
	if visible then
		mode.add_key_bindings(keys)
		update()
	else
		timeout:kill()
		mode.remove_key_bindings(keys)
		osd:remove()
	end
end

mp.register_script_message('toggle', function()
	timeout:kill()
	visible = not visible
	ignore_once = false
	file_loaded = true
	update_menu()
end)
