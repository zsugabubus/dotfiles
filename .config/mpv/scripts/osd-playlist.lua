local osd = mp.create_osd_overlay("ass-events")
local visible = false
local timeout = mp.add_timeout(mp.get_property_number('osd-duration') / 1000, function()
	handle_message('toggle')
end)
timeout:kill()

function update()
	mp.register_idle(_update)
end

function _update()
	mp.unregister_idle(_update)

	local width, height, ratio = mp.get_osd_size()
	if 0 == height then
		height = 1
	end
	local pos = mp.get_property_number('playlist-pos-1')
	local playlist = mp.get_property_native('playlist')

	local rtl = false
	local font_scale = 0.75
	local font_size = mp.get_property_number('osd-font-size')
	-- Trim a half-half line from top and bottom to make visually a bit more pleasant.
	local margin_v = mp.get_property_number('osd-margin-y') + font_size / 4
	local y = font_size + font_size / 4
	osd.data = ('{\\r\\bord2\\pos(0, %d)\\fnmpv-osd-symbols}'):format(y)

	local max = math.floor((900 - margin_v - y) / font_size)

	local from = pos - math.floor(max * 0.2)
	if from < 1 then
		from = 1
	end
	local to = from + max
	if #playlist < to then
		to = #playlist
		from = to - max
		if from < 1 then
			from = 1
		end
	end

	local NBSP = '\194\160'
	local RIGHT_ARROW = '\226\158\156'
	for i=from,to do
		local item = playlist[i]

		local display = item.filename:gsub('^./', '')

		-- Find potential space replacement.
		local space, space_count = ' ', 0
		if not display:find(space) then
			for _, fake_space in pairs({'%.', '-', '%_'}) do
				local count = select(2, display:gsub(fake_space, ''))
				if space_count < count then
					space, space_count = fake_space, count
				end
			end
		end

		if 80 < #display then
			local HORIZONTAL_ELLIPSIS = '\226\128\166'
			display = display:gsub('/.*/', '/' .. HORIZONTAL_ELLIPSIS .. '/')
		end

		display = display
			:gsub(space, NBSP)
			-- Hehh.
			:gsub(' [0-9]+p[^/]*$', '')
			-- Trim extension.
			:gsub('%.[0-9A-Za-z]+$', '')

		osd.data = osd.data ..
			('\\N{\\r\\b0\\fscx%f\\fscy%f}'):format(font_scale * 100, font_scale * 100) ..
			'{\\alpha&H00}' ..
			(rtl
				and (
					item.current and '{\\b1}' or ''
				)
				or (
					NBSP ..
					(item.current and '{\\b1}' or '{\\alpha&HFF}') ..
					RIGHT_ARROW ..
					'{\\alpha&H00}' ..
					NBSP
				)
			) ..
			display ..
			(rtl
				and (
					(item.current and '' or '{\\alpha&HFF}') ..
					'<'
				)
				or ''
			)
	end

	osd:update()
end

function handle_message(action)
	timeout:kill()
	if action == 'show' then
		visible = true
	elseif action == 'hide' then
		visible = false
	elseif action == 'toggle' or
	       action == 'blink' then
		-- Otherwise it already contains the negated value.
		if not timeout.is_enabled() then
			visible = not visible
		end
		if action == 'blink' then
			timeout:resume()
		end
	end

	if visible then
		mp.observe_property('playlist', nil, update)
		mp.observe_property('playlist-pos', nil, update)
	else
		mp.unobserve_property(update)
		osd:remove()
	end
end

for _, action in pairs({'show', 'hide', 'blink', 'toggle'}) do
	mp.register_script_message(action, function() handle_message(action) end)
end
