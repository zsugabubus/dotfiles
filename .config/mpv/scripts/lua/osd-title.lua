local osd = require('osd').new({ z = 10 })
local utils = require('utils')
local title = require('title')

local visible = false
local props = {}

local old_visible

local update

local function set_visible(action)
	visible = utils.reduce_bool(visible, action)
	update()
end

local function update_property(name, value)
	props[name] = value
	update()
end

local function osd_put_block(align, ...)
	osd:n()
	osd:an(align)
	osd:bord(2)
	osd:fsc(70)
	osd:c1(0x00ffff)
	osd:putf(...)
end

function update()
	if old_visible ~= visible then
		old_visible = visible

		mp.unobserve_property(update_property)

		if visible then
			mp.observe_property('audio-params', 'native', update_property)
			mp.observe_property('duration', 'native', update_property)
			mp.observe_property('playlist-count', 'native', update_property)
			mp.observe_property('playlist-pos', 'native', update_property)
			mp.observe_property('track-list', 'native', update_property)
			mp.observe_property('video-params', 'native', update_property)
		else
			osd:remove()
		end

		return
	end

	if not visible then
		return
	end

	osd:clear()

	osd_put_block(2, '%s', title.get_current_ass(osd))

	for _, track in ipairs(props['track-list'] or {}) do
		if track.selected then
			if track.type == 'video' then
				local pars = props['video-params']
				if pars then
					osd_put_block(
						3,
						'%s%dx%d',
						track.albumart and '[P] ' or '',
						pars.w,
						pars.h
					)
				end
				break
			elseif track.type == 'audio' then
				local pars = props['audio-params']
				if pars then
					osd_put_block(3, '%s %s', track.codec, pars['hr-channels'])
				end
			end
		end
	end

	local duration = props['duration']
	if duration then
		osd_put_block(3, ' %02d:%02d', duration / 60, duration % 60)
	end

	osd_put_block(
		1,
		'%d/%d',
		props['playlist-pos'] or 0,
		props['playlist-count'] or 0
	)

	osd:update()
end
update = osd.update_wrap(update)

utils.register_script_messages('osd-title', {
	visibility = set_visible,
})

update()
