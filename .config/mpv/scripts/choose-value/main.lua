local Mode = require('mode')
local utils = require('mp.utils')

local script_opts = mp.command_native({'expand-path', '~~/script-opts'})
local scripts = mp.command_native({'expand-path', '~~/scripts'})

function cycle_values(property, opts_file)
	local options = require('mp.options')
	local osd = require('osd').new()

	local mode
	local values
	local visible = false

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
			local key, value, display = unpack(x)
			local selected = current == value
			any_selected = any_selected or selected
			osd:append(
				'\\N{\\b', selected and '1' or '0', '}',
				key, ': ', display or value
			)
		end

		if not any_selected then
			osd:append('\\N{\\b1}_: ', current)
		end

		osd:update()
	end
	local function update()
		mp.unregister_idle(_update)
		mp.register_idle(_update)
	end

	local function update_menu()
		mp.unobserve_property(update)

		if visible then
			values  = dofile(('%s/%s'):format(script_opts, opts_file))

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

			mode = Mode(keys)
			mp.observe_property(property, nil, update)
			mode:add_key_bindings()
		else
			mode:remove_key_bindings()
			mode = nil
			values = nil
			osd:remove()
		end
	end

	mp.register_script_message(property, function()
		visible = not visible
		update_menu()
	end)
end

for _, file in pairs(utils.readdir(script_opts, 'files')) do
	local property, a, b = file:match('^prop%-(.*)%.lua$')
	if property ~= nil then
		cycle_values(property, file)
	end
end

