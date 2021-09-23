local NBSP = '\194\160'
local RIGHT_ARROW = '\226\158\156'

local utils = require('mp.utils')
local script_opts = mp.command_native({'expand-path', '~~/script-opts'})
local mode = dofile(mp.get_script_directory() .. '/mode.lua')
local osd = mp.create_osd_overlay('ass-events')
local visible = false
local tab
local current = {af=1, vf=1}
local filters = {}

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
	select_abs(current[tab] + n)
end

local keys = {
	HOME=function() select_abs(1) end,
	END=function() select_abs(999) end,
	g='HOME',
	['Shift+g']='END',
	j='DOWN',
	k='UP',
	['Shift+j']='Shift+DOWN',
	['Shift+k']='Shift+UP',
	DOWN=function() select_rel(1) end,
	UP=function() select_rel(-1) end,
	['Shift+DOWN']=function() move_rel(1) end,
	['Shift+UP']=function() move_rel(-1) end,
	TAB=function()
		tab = tab == 'af' and 'vf' or 'af'
		update()
	end,
	Space=function()
		local f, i = filters[tab], current[tab]
		if f[i] ~= nil then
			f[i].enabled = not f[i].enabled
			mp.set_property_native(tab, f)
		end
	end,
	DEL=function()
		local f, i = filters[tab], current[tab]
		f[i] = nil
	end,
	D='DEL',
	r=function()
		mp.set_property(tab, table.concat(dofile(script_opts .. '/filters.lua')[tab], ','))
	end,
	a=function()
		tab = 'af'
		update()
	end,
	v=function()
		tab = 'vf'
		update()
	end,
	q=function()
		visible = false
		update_menu()
	end,
	ESC='q',
}
for i=1,9 do
	keys[string.char(string.byte('0') + i)] =
		function() select_abs(i) end
end

function avdict_to_string(o)
	local s = {}
	for k,v in pairs(o) do
		table.insert(s, table.concat{k, '=', v})
	end
	return table.concat(s, ':')
end

function print_filters(name, t)
	table.insert(osd.data, table.concat{
		'{\\r}', name, NBSP, 'Filters:'})
	filters[t] = mp.get_property_native(t)

	local f = filters[t]

	if current[t] < 1 then
		current[t] = #f
	elseif #f < current[t] then
		current[t] = 1
	end

	if #f == 0 then
		table.insert(osd.data, table.concat{
			(t == tab and '{\\b1}' or ''), NBSP, 'none'})
	end
	for i=1,#f do
		local pars = f[i].params
		local enabled = f[i].enabled
		local selected = t == tab and i == current[t]
		table.insert(osd.data, table.concat{
			'\\N{\\r\\b1}',
			(selected and '' or '{\\alpha&HFF}'),
			RIGHT_ARROW,
			(selected and '' or '{\\b0}'),
			'{\\alpha&H00}', NBSP,
			(enabled and '●' or '○'), NBSP})
		table.insert(osd.data, table.concat({
			i, ':', NBSP}))
		table.insert(osd.data, table.concat({
			f[i].name, NBSP,
			(pars.graph and '[' .. pars.graph .. ']' or avdict_to_string(pars))}))
	end
	table.insert(osd.data, '\\N')
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

	osd.data = {NBSP .. '\n'}
	print_filters('Audio', 'af')
	table.insert(osd.data, '\\N')
	print_filters('Video', 'vf')

	osd.data = table.concat(osd.data)
	osd:update()
end

function update_menu()
	if visible then
		mp.observe_property('af', 'none', update)
		mp.observe_property('vf', 'none', update)
		mode.add_key_bindings(keys)
	else
		mp.unobserve_property(update)
		mode.remove_key_bindings(keys)
		osd:remove()
	end
end

mp.add_key_binding('F', 'toggle', function()
	visible = not visible
	update_menu()
end)

keys.v()
keys.r()
keys.a()
keys.r()
