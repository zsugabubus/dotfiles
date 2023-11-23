local osd = require('osd').new()
local mode = require('mode').new()
local utils = require('utils')

local visible = false
local cursor_tab, cursor_id = 'af', 0
local props = { vf = {}, af = {} }

local old_visible

local update

local function set_visible(action)
	visible = utils.reduce_bool(visible, action)
	update()
end

local function set_cursor(action)
	local n = #props[cursor_tab]
	if action == 'up' then
		cursor_id = cursor_id - 1
		if cursor_id < 1 then
			return set_cursor('last')
		end
	elseif action == 'down' then
		cursor_id = cursor_id + 1
		if cursor_id > n then
			return set_cursor('first')
		end
	elseif action == 'first' then
		cursor_id = 1
	elseif action == 'last' then
		cursor_id = n
	elseif action == 'audio' then
		cursor_tab, cursor_id = 'af', 1
	elseif action == 'video' then
		cursor_tab, cursor_id = 'vf', 1
	elseif type(action) == 'number' then
		if action <= 0 or action > n then
			return false
		end
		cursor_id = action
	end

	update()

	return true
end

local function move_cursor(action)
	local list = props[cursor_tab]
	local x = cursor_id
	local y = x + (action == 'up' and -1 or 1)

	if list[x] and list[y] then
		list[x], list[y] = list[y], list[x]
		cursor_id = y
		mp.set_property_native(cursor_tab, list)
	end
end

local function delete_cursor(action)
	table.remove(props[cursor_tab], cursor_id)
	mp.set_property_native(cursor_tab, props[cursor_tab])
end

local function set_enabled(action)
	local current = props[cursor_tab][cursor_id]
	if current then
		current.enabled = utils.reduce_bool(current.enabled, action)
		mp.set_property_native(cursor_tab, props[cursor_tab])
	end
end

local function set_default_filters()
	local defaults = utils.do_script_opt('filters.lua') or {}
	for _, k in pairs({ 'af', 'vf' }) do
		mp.set_property(k, table.concat(defaults[k] or {}, ','))
	end
end

local function update_property(name, value)
	props[name] = value

	if name == cursor_tab then
		cursor_id = math.max(1, cursor_id)
		cursor_id = math.min(cursor_id, #value)
	end

	update()
end

local function osd_put_avdict(o)
	local first = true
	for k, v in pairs(o) do
		if not first then
			osd:put(':')
		end
		osd:put(k, '=', v)
		first = false
	end
end

local function osd_put_filters(name, t)
	osd:putf('{\\b1}%s{\\b0} Filters:', name)

	local filters = props[t]

	if #filters == 0 then
		osd:put('\\h')
		local current = t == cursor_tab
		osd:put_cursor(current)
		osd:put('(none)')
		osd:put_rcursor(current)
	end

	for i = 1, #filters do
		local pars = filters[i].params
		local enabled = filters[i].enabled
		local current = t == cursor_tab and i == cursor_id

		osd:put('\\N')
		osd:put_cursor(current)
		osd:put_marker(enabled)
		osd:put(i, ':\\h', filters[i].name, ' ')

		if pars.graph then
			osd:put('[', pars.graph, ']')
		else
			osd_put_avdict(pars)
		end
		osd:put_rcursor(current)
	end
	osd:put('\\N')
end

function update()
	if old_visible ~= visible then
		old_visible = visible

		mp.unobserve_property(update_property)

		if visible then
			mp.observe_property('af', 'native', update_property)
			mp.observe_property('vf', 'native', update_property)
			osd.observe_fsc_properties(update_property)
			mode:add_key_bindings()
		else
			mode:remove_key_bindings()
			osd:remove()
		end

		return
	end

	if not visible then
		return
	end

	osd:reset()
	osd:put_fsc(props, 1 + #props.af + 1 + 1 + #props.vf, 0.9)
	osd:put('{\\fnmpv-osd-symbols}')

	osd_put_filters(osd.VIDEO_ICON .. ' Video', 'vf')
	osd:put('\\N')
	osd_put_filters(osd.AUDIO_ICON .. ' Audio', 'af')

	osd:update()
end
update = osd.update_wrap(update)

mode:map({
	a = function()
		set_cursor('audio')
	end,
	v = function()
		set_cursor('video')
	end,
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
	['Shift+UP'] = function()
		move_cursor('up')
	end,
	['Shift+DOWN'] = function()
		move_cursor('down')
	end,
	TAB = function()
		set_cursor(cursor_tab == 'af' and 'video' or 'audio')
	end,
	SPACE = function()
		set_enabled('toggle')
	end,
	DEL = function()
		delete_cursor()
	end,
	r = set_default_filters,
	F5 = 'r',
	['0..9'] = function(i)
		if set_cursor(i) then
			set_enabled('toggle')
		end
	end,
	ESC = function()
		set_visible('hide')
	end,
})

utils.register_script_messages('osd-filters', {
	visibility = set_visible,
	cursor = set_cursor,
})

set_default_filters()
update()
