local imdb = require('imdb')
local osd = require('osd').new({ z = 100 })

local update
local visible
local old_visible
local title
local search_result
local cache = {}

local function set_video_by_title(url, title)
	local add = true
	for _, track in ipairs(mp.get_property_native('track-list')) do
		if track.type == 'video' and track.title == title then
			if add and track['external-filename'] == url then
				add = false
			else
				mp.commandv('video-remove', track.id)
			end
		end
	end
	if add and url then
		mp.commandv('video-add', url, 'auto', title)
	end
end

local function set_search_result(result)
	search_result = result
	set_video_by_title(result and result.image_url, 'IMDB')
end

local timer = mp.add_timeout(0.5, function()
	local search_title = title
	local duration = mp.get_property_native('duration')
	imdb.search_title(search_title, duration, function(result)
		cache[search_title] = result
		if search_title == title then
			set_search_result(result)
			update()
		end
	end)
end, true)

local function update_property(_, value)
	title = value
	set_search_result(cache[title])
	update()
	timer:kill()
	if not search_result and title then
		timer:resume()
	end
end

function update()
	if old_visible ~= visible then
		old_visible = visible

		mp.unobserve_property(update_property)

		if visible then
			mp.observe_property('media-title', 'native', update_property)
		else
			osd:remove()
		end

		return
	end

	if not visible then
		return
	end

	osd:clear()
	osd:an(9)
	osd:bold(true)

	if search_result then
		osd:put(('%.1f'):format(search_result.rating))
		osd:n()
		osd:fsc(40)
		osd:an(9)
		osd:bold(true)
		osd:put(('%s (%s)'):format(search_result.title, search_result.year))
	else
		osd:put('-')
	end

	osd:update()
end

mp.add_key_binding(nil, 'imdb', function()
	visible = not visible
	update()
end)
