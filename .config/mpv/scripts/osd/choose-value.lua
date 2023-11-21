local utils = require('utils')

local function build_chooser(name, choices_file)
	local osd = require('osd').new()

	local visible = false
	local is_property = mp.get_property(name) ~= nil
	local mode
	local choices
	local props = {}

	local old_visible

	local update

	local function set_visible(action)
		visible = utils.reduce_bool(visible, action)
		update()
	end

	local function update_choices()
		choices = utils.do_script_opt(choices_file)

		mode = require('mode').new()

		mode:map({
			ESC = function()
				set_visible('hide')
			end,
		})

		for _, choice in ipairs(choices) do
			local key, value = unpack(choice)
			mode:map(key, function()
				set_visible('hide')
				if is_property then
					mp.commandv('osd-msg-bar', 'set', name, value)
				elseif type(value) == 'string' then
					mp.command(value)
				else
					value()
				end
			end)
		end

		update()
	end

	local function update_property(name, value)
		props[name] = value
		update()
	end

	function update()
		if old_visible ~= visible then
			old_visible = visible

			mp.unobserve_property(update)

			if visible then
				update_choices()
				mp.observe_property(name, 'native', update_property)
				osd.observe_fsc_properties(update_property)
				mode:add_key_bindings()
			elseif mode then
				mode:remove_key_bindings()
				osd:remove()
				mode = nil
				choices = nil
			end
		end

		if not visible then
			return
		end

		osd:reset()
		osd:put_fsc(props, 1 + #choices)
		osd:putf('Choose %s:', name)

		local current = props[name]
		for _, choice in pairs(choices) do
			local key, value, display = unpack(choice)

			osd:put('\\N')
			if current ~= nil then
				osd:put_marker(value == current)
			end
			osd:put(key, ':\\h', display or value)
		end

		osd:update()
	end
	update = osd.update_wrap(update)

	utils.register_script_messages('choose-' .. name, {
		visibility = set_visible,
	})

	update()
end

for _, file in ipairs(require('mp.utils').readdir(utils.script_opts, 'files')) do
	local name = string.match(file, '^choose%-(.*)%.lua$')
	if name then
		build_chooser(name, file)
	end
end
