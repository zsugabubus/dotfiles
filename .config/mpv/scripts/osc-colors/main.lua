local OPTIONS = {
	{option='brightness', icon=0xa},
	{option='contrast',   icon=0x7},
	{option='gamma',      icon=0xa},
	{option='saturation', icon=0x8},
	{option='hue',        icon=0xb},
}

local Mode = require('mode')
local options = require('mp.options')
local osd = require('osd')
local utils = require('mp.utils')

local visible = false
local current = OPTIONS[1].option

local opts = {
	font_scale = 0.9,
}
options.read_options(opts, nil, update)

local script_opts = mp.command_native({'expand-path', '~~/script-opts'})
local PRESETS = select(2, pcall(dofile, script_opts .. '/color-presets.lua')) or {
	{name='(none)'},
	{name='tv', b=2, c=3, g=3, s=3 },
	{name='movie',  b=0, c=27, g=2, s=11 },
}

local ignore_once, file_loaded = true, false
mp.register_event('end-file', function()
	file_loaded, visible = false, false
	update_menu()
end)
mp.register_event('playback-restart', function()
	file_loaded = true
end)

local timeout = mp.add_timeout(mp.get_property_number('osd-duration') / 1000, function()
	visible = false
	update_menu()
end)
timeout:kill()

local function select_abs(i)
	local preset = PRESETS[i]
	for _, x in ipairs(OPTIONS) do
		mp.set_property_number(x.option, preset[x.option:sub(1, 1)] or 0)
	end
	mp.osd_message(('Color preset: %s'):format(preset.name))
end

local function select_rel(n)
	local i = 1
	for k, preset in pairs(PRESETS) do
		local match = true
		for _, x in ipairs(OPTIONS) do
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
	q={'quit', function()
		visible = false
		update_menu()
	end},
	ESC='q',
	ENTER='q',
	n={'switch preset', function() select_rel(1) end},
	p={'switch preset', function() select_rel(-1) end},
	r={'reset', function() mp.commandv('osd-bar', 'set', current, 0) end},
	R={'reset all', function()
		for _, x in ipairs(OPTIONS) do
			mp.commandv('osd-bar', 'set', x.option, 0)
		end
	end},

	x={'change', function() mp.commandv('osd-bar', 'add', current, -1) end},
	a={'change', function() mp.commandv('osd-bar', 'add', current,  1) end},
	LEFT='x',
	RIGHT='a',
	DOWN='LEFT',
	UP='RIGHT',
	j='x',
	k='a',
	['-']='x',
	['+']='a',

	X={'change big', function() mp.commandv('osd-bar', 'add', current, -3) end},
	A={'change big', function() mp.commandv('osd-bar', 'add', current,  3) end},
	['Shift+LEFT']='X',
	['Shift+RIGHT']='A',
	['Shift+DOWN']='Shift+LEFT',
	['Shift+UP']='Shift+RIGHT',
	J='X',
	K='A',

	['0..9']={'switch preset'},
}
for _, x in ipairs(OPTIONS) do
	keys[x.option:sub(1, 1)] = {
		'change ' .. x.option,
		function()
			current = x.option
			mp.commandv('osd-bar', 'add', x.option,  1)
		end,
	}
	keys[x.option:sub(1, 1):upper()] = {
		'change ' .. x.option,
		function()
			current = x.option
			mp.commandv('osd-bar', 'add', x.option, -1)
		end,
	}
end
for i=0,9 do
	keys[string.char(string.byte('0') + i)] =
		function()
			ignore_once, visible = true, false
			select_abs(i + 1)
			update_menu()
		end
end
local mode = Mode(keys)

mp.register_script_message('next-preset', keys.n[2])
mp.register_script_message('prev-preset', keys.p[2])

local function _update()
	mp.unregister_idle(_update)

	if ignore_once or not file_loaded then
		ignore_once = false
		return
	end

	osd.data = {
		('\\h\n{\\q2\\fscx%d\\fscy%d}'):format(
			opts.font_scale * 100, opts.font_scale * 100),
	}

	for _, x in ipairs(OPTIONS) do
		if visible then
			local selected = current == x.option
			osd:append(
				(selected and '' or '{\\alpha&HFF}'),
				osd.RIGHT_ARROW,
				(selected and '' or '{\\b0}'),
				'{\\alpha&H00} ')
		end

		osd:append(
			"{\\fnmpv-osd-symbols}\238\128", string.char(128 + x.icon), ' ',
			x.option:sub(1, 1):upper(), x.option:sub(2), ': ',
			mp.get_property_number(x.option), '\\N')
	end

	if visible then
		osd:append('\\h\n{\\q2\\fscx75\\fscy75}', 'Available Presets:')
		for i, preset in ipairs(PRESETS) do
			osd:append('\\N', i - 1, ': ', preset.name)
		end

		osd:append(mode:get_ass_help())
	end

	osd.data = table.concat(osd.data)
	osd:update()

	timeout:kill()
	if not visible then
		timeout:resume()
	end
end
function update()
	mp.unregister_idle(_update)
	mp.register_idle(_update)
end

for _, x in ipairs(OPTIONS) do
	mp.observe_property(x.option, nil, function()
		selected = x.option
		update()
	end)
end

function update_menu()
	if visible then
		mode:add_key_bindings()
		update()
	else
		timeout:kill()
		mode:remove_key_bindings()
		osd:remove()
	end
end

mp.register_script_message('toggle', function()
	visible = not visible
	ignore_once, file_loaded = false, true
	update_menu()
end)
