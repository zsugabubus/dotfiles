local NBSP = '\194\160'
local RIGHT_ARROW = '\226\158\156'
local HORIZONTAL_ELLIPSIS = '\226\128\166'

local options = require('mp.options')

local osd = mp.create_osd_overlay('ass-events')
local visible = false

local opts = {
	font_scale = 0.65,
}
options.read_options(opts, nil, update)

local prev_pos = 0
local forward = true
mp.observe_property('playlist-pos', 'number', function(_, pos)
	if prev_pos ~= pos then
		forward = prev_pos <= pos
		prev_pos = pos
	end
end)

function get_height()
	local font_size = mp.get_property_number('osd-font-size')
	local scaled_font_size = font_size * opts.font_scale

	local margin_y = 2 * mp.get_property_number('osd-margin-y')
	local playlist_y = osd.res_y - margin_y - font_size
	-- Subtract one line so it is visually a bit more pleasant.
	local nlines = math.floor(playlist_y / scaled_font_size) - 1

	return nlines, font_size + (playlist_y - nlines * scaled_font_size) / 2
end

function osd_append(...)
	for _, s in ipairs({...}) do
		osd.data[#osd.data + 1] = s
	end
end

function update()
	mp.unregister_idle(_update)
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
	local nlines, y = get_height()

	local from = pos - math.floor(nlines * (forward and 0.2 or 0.8))
	if from < 1 then
		from = 1
	end
	local to = from + nlines
	if #playlist < to then
		to = #playlist
		from = to - nlines
		if from < 1 then
			from = 1
		end
	end

	osd.data = {
		('{\\pos(0, %d)}'):format(y),
		('{\\fscx%f\\fscy%f}'):format(opts.font_scale * 100, opts.font_scale * 100),
	}

	local ass_style = {}
	for _, current in ipairs({false, true}) do
		ass_style[current] = table.concat{
			'\\N',
			'{\\alpha&H00}', NBSP,
			'{\\b1}',
			(current and '' or '{\\alpha&HFF}'),
			RIGHT_ARROW,
			(current and '' or '{\\b0}'),
			'{\\alpha&H00}', NBSP,
		}
	end

	for i=from,to do
		local item = playlist[i]

		local display = item.title
		if not display then
			display = item.filename:gsub('^./', '')

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
				display = display:gsub('/.*/', '/' .. HORIZONTAL_ELLIPSIS .. '/')
			end

			display = display
				:gsub(space, NBSP)
				-- Hehh.
				:gsub(NBSP .. '[0-9]+p[^/]*', '')
				:gsub(NBSP .. '[1-9][0-9][0-9][0-9]' .. NBSP .. '[A-Za-z0-9][^/]', '')
				-- Trim extension.
				:gsub('([^/])%.[0-9A-Za-z]+$', '%1')
				-- ASS escape.
				:gsub('[\\{]', '\\%0')
		end

		osd_append(ass_style[item.current or false], display)
	end

	osd.data = table.concat(osd.data)
	osd:update()
end

local timeout = mp.add_timeout(mp.get_property_number('osd-duration') / 1000, function()
	handle_message('toggle')
end)
timeout:kill()

function handle_message(action)
	timeout:kill()

	local temporary = false
	if action == 'show' or action == 'peek' then
		temporary = action == 'peek' and (not visible or timeout:is_enabled())
		visible = true
	elseif action == 'hide' then
		visible = false
	elseif action == 'toggle' or action == 'blink' then
		visible = not visible
		temporary = action == 'blink'
	end

	if temporary then
		timeout:resume()
	end

	if visible then
		mp.observe_property('playlist', nil, update)
		mp.observe_property('playlist-pos', nil, update)
	else
		mp.unobserve_property(update)
		osd:remove()
	end
end

for _, action in pairs({'show', 'peek', 'hide', 'toggle', 'blink'}) do
	mp.register_script_message(action, function() handle_message(action) end)
end

function half_scroll(dir)
	local nlines = get_height()
	local pos = dir * math.floor((nlines + 1) / 2) + mp.get_property_number('playlist-pos')
	pos = math.max(0, pos)
	pos = math.min(mp.get_property_number('playlist-count') - 1, pos)
	mp.set_property_number('playlist-pos', pos)
end

mp.add_key_binding('Ctrl+d', 'half-down', function() half_scroll(1) end)
mp.add_key_binding('Ctrl+u', 'half-up', function() half_scroll(-1) end)
