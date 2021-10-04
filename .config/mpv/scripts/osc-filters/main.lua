local NBSP = '\194\160'
local RIGHT_ARROW = '\226\158\156'

local Mode = require('mode')
local options = require('mp.options')
local utils = require('mp.utils')

local script_opts = mp.command_native({'expand-path', '~~/script-opts'})
local osd = mp.create_osd_overlay('ass-events')
local visible = false
local tab
local current = {af=1, vf=1}
local filters = {}

local opts = {
	font_scale = 0.9,
}
options.read_options(opts, nil, update)

function move_rel(n)
	local f, old = filters[tab], current[tab]
	local new = old + n

	if f[old] ~= nil and f[new] ~= nil then
		f[old], f[new] = f[new], f[old]
		current[tab] = new
		mp.set_property_native(tab, f)
	end
end

function select_abs(n)
	current[tab] = n
	update()
end

function select_rel(n)
	local f = filters[tab]
	n = current[tab] + n
	if n < 1 then
		n = #f
	elseif #f < n then
		n = 1
	end
	select_abs(n)
end

local keys = {
	HOME={'select', function() select_abs(1) end},
	END={'select', function() select_abs(999) end},
	g='HOME',
	G='END',
	DOWN={'select', function() select_rel(1) end},
	UP={'select', function() select_rel(-1) end},
	j='DOWN',
	k='UP',
	['Shift+DOWN']={'move', function() move_rel(1) end},
	['Shift+UP']={'move', function() move_rel(-1) end},
	J='Shift+DOWN',
	K='Shift+UP',
	TAB={'select type', function()
		tab = tab == 'af' and 'vf' or 'af'
		update()
	end},
	SPACE={'toggle enabled', function()
		local f, i = filters[tab], current[tab]
		if f[i] ~= nil then
			f[i].enabled = not f[i].enabled
			mp.set_property_native(tab, f)
		end
	end},
	DEL={'delete', function()
		local f, i = filters[tab], current[tab]
		f[i] = nil
	end},
	D='DEL',
	r={'reset type', function()
		mp.set_property(tab, table.concat(dofile(script_opts .. '/filters.lua')[tab], ','))
	end},
	a={'audio', function()
		tab = 'af'
		update()
	end},
	v={'video', function()
		tab = 'vf'
		update()
	end},
	q={'quit', function()
		visible = false
		update_menu()
	end},
	ESC='q',
	['0..9']={'select'},
}
for i=1,9 do
	keys[string.char(string.byte('0') + i)] =
		function() select_abs(i) end
end

local mode = Mode(keys)

function osd_append(...)
	for _, s in ipairs({...}) do
		osd.data[#osd.data + 1] = s
	end
end

function osd_append_avdict(o)
	local first = true
	for k, v in pairs(o) do
		if not first then
			osd_append(':')
		end
		first = false
		osd_append(k, '=', v)
	end
end

function osd_append_filters(name, t)
	filters[t] = mp.get_property_native(t)
	local f = filters[t]

	if current[t] < 1 then
		current[t] = 1
	elseif #f < current[t] then
		current[t] = #f
	end

	osd_append(name, NBSP, 'Filters:')

	if #f == 0 then
		osd_append((t == tab and '{\\b1}' or ''), NBSP, 'none')
	end
	for i=1,#f do
		local pars = f[i].params
		local enabled = f[i].enabled
		local selected = t == tab and i == current[t]
		osd_append(
			'\\N{\\b1}',
			(selected and '' or '{\\alpha&HFF}'),
			RIGHT_ARROW,
			(selected and '' or '{\\b0}'),
			'{\\alpha&H00}', NBSP,
			(enabled and '●' or '○'), NBSP,
			i, ':', NBSP,
			f[i].name, NBSP)

		if pars.graph then
			osd_append('[', pars.graph, ']')
		else
			osd_append_avdict(pars)
		end
	end
	osd_append('{\\b0}\\N')
end

function update()
	mp.unregister_idle(_update)
	mp.register_idle(_update)
end
function _update()
	mp.unregister_idle(_update)

	if not visible then
		return
	end

	osd.data = {
		NBSP .. '\n',
		('{\\fscx%d\\fscy%d}'):format(opts.font_scale * 100, opts.font_scale * 100),
	}

	osd_append_filters('Audio', 'af')
	osd_append('\\N')
	osd_append_filters('Video', 'vf')

	osd_append(mode:get_ass_help())

	osd.data = table.concat(osd.data)
	osd:update()
end

function update_menu()
	mp.unobserve_property(update)

	if visible then
		mp.observe_property('af', 'none', update)
		mp.observe_property('vf', 'none', update)
		mode:add_key_bindings()
	else
		mode:remove_key_bindings()
		osd:remove()
	end
end

mp.add_key_binding('F', 'toggle', function()
	visible = not visible
	update_menu()
end)

keys.v[2]()
keys.r[2]()
keys.a[2]()
keys.r[2]()
