local osd = mp.create_osd_overlay("ass-events")

local visible = false

function update()
	mp.register_idle(_update)
end
function _update()
	mp.unregister_idle(_update)

	local width, height, ratio = mp.get_osd_size()
	local pos = mp.get_property_number('playlist-pos-1')
	local playlist = mp.get_property_native('playlist')

	local font_scale = 0.75
	local font_size = mp.get_property_number('osd-font-size')
	-- Trim a half-half line from top and bottom to make visually a bit more pleasant.
	local margin_v = mp.get_property_number('osd-margin-y') + font_size / 4
	local y = font_size + font_size / 4
	osd.data = ('{\\r\\pos(0,%d)\\bord2\\fnmonospace\\an7\\fnmpv-osd-symbols}'):format(y)
	local max = math.floor((900 - margin_v - y) / font_size)

	local from = pos - math.floor(max * 0.2)
	if from < 1 then
		from = 1
	end
	local to = from + max

	if #playlist < to then
		to = #playlist
		from = to - max
	end
	if from < 1 then
		from = 1
	end

	local NBSP = '\194\160'
	local RIGHT_ARROW = '\226\158\156'
	for i=from,to do
		local item = playlist[i]
		osd.data = osd.data ..
		('\\N{\\r\\b0\\fscx%f\\fscy%f}'):format(font_scale * 100, font_scale * 100) ..
		NBSP ..
		'{\\alpha&H00}' ..
		(item.current and '{\\b1}' or '{\\alpha&HFF}') ..
		RIGHT_ARROW ..
		'{\\alpha&H00}' ..
		NBSP ..'{\\fnmonospace}'..
		string.gsub(
		string.gsub(item.title or item.filename,
		'^./', ''),
		'[ _]', NBSP)
	end
	osd:update()
end

function handle_message(state)
	if state == 'show' then
		visible = true
	elseif state == 'hide' then
		visible = false
	elseif state == 'toggle' then
		visible = not visible
	end

	if visible then
		mp.observe_property('playlist', nil, update)
		mp.observe_property('playlist-pos', nil, update)
		update()
	else
		mp.unobserve_property(update)
		osd:remove()
	end
end

for _, state in pairs({'show', 'hide', 'toggle'}) do
	mp.register_script_message(state, function() handle_message(state) end)
end
