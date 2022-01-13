local Mode = require('mode')
local utils = require('mp.utils')

function cycle_values(property, values)
	local options = require('mp.options')
	local osd = require('osd')

	local visible = false

	local keys = {
		q={'quit', function()
			visible = false
			update_menu()
		end},
		ESC='q',
		['other']={'select'},
	}
	for _, x in ipairs(values) do
		local key, value = unpack(x)
		keys[key] =
			function()
				mp.commandv('osd-msg-bar', 'set', property, value)
				visible = false
				update_menu()
			end
	end

	local mode = Mode(keys)

	local function _update()
		mp.unregister_idle(_update)

		if not visible then
			return
		end

		osd.data = {
			'\\h\n{\\q2}',
		}

		local current = mp.get_property_native(property)
		local any_selected = false
		for _, x in pairs(values) do
			local key, value = unpack(x)
			local selected = current == value
			any_selected = any_selected or selected
			osd:append(
				'\\N{\\b', selected and '1' or '0', '}',
				key, ': ', value
			)
		end

		if not any_selected then
			osd:append('\\N{\\b1}_: ', current)
		end

		osd:append(mode:get_ass_help())

		osd:update()
	end
	function update()
		mp.unregister_idle(_update)
		mp.register_idle(_update)
	end

	function update_menu()
		mp.unobserve_property(update)

		if visible then
			mp.observe_property(property, nil, update)
			mode:add_key_bindings()
		else
			mode:remove_key_bindings()
			osd:remove()
		end
	end

	mp.register_script_message(property, function()
		visible = not visible
		update_menu()
	end)
end

local script_opts = mp.command_native({'expand-path', '~~/script-opts'})
local scripts = mp.command_native({'expand-path', '~~/scripts'})

for _, file in pairs(utils.readdir(script_opts, 'files')) do
	local property, a, b = file:match('^prop%-(.*)%.lua$')
	if property ~= nil then
		local values = dofile(script_opts .. '/' .. file)
		cycle_values(property, values)
	end
end

