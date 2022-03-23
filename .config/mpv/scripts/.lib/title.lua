local HORIZONTAL_ELLIPSIS = '\226\128\166'
local SP_PATS = {'%.', '-', '%_'}
local HE_PATH = '/' .. HORIZONTAL_ELLIPSIS .. '/'

local Osd = require('osd')

local cache = {}

local function sub_hex2str(x)
	return string.char(tonumber(x, 16))
end

local function get_playlist_entry(item)
	s = cache[item.title]
	if s ~= nil then
		return s
	elseif item.title ~= nil then
		s = Osd.ass_escape(item.title)
		cache[item.title] = s
		return s
	end

	local s = cache[item.filename]
	if s ~= nil then
		return s
	end

	s = item.filename:gsub('^./', '')

	if 80 < #s then
		s = s:gsub('/.*/', HE_PATH)
	end

	local orig = s
	-- Encodes a multi-byte character.
	if s:match('_%x%x_%x%x') then
		s = s:gsub('_(%x%x)', sub_hex2str)
	end
	if s == orig then
		-- Find potential space replacement.
		local space, space_count = ' ', 0
		if not s:find(space) then
			for _, fake_space in pairs(SP_PATS) do
				local count = select(2, s:gsub(fake_space, ''))
				if space_count < count then
					space, space_count = fake_space, count
				end
			end
		end
		s = s:gsub(space, ' ')
	end

	s = s
		-- Hehh.
		:gsub(' [0-9]+p[^/]*', '')
		:gsub(' [1-9][0-9][0-9][0-9] [A-Za-z0-9][^/]', '')
		-- Trim extension.
		:gsub('([^/])%.[0-9A-Za-z]+$', '%1')

	s = Osd.ass_escape(s)
	cache[item.filename] = s
	return s
end

function get_current()
	local artist = mp.get_property_native('metadata/by-key/Artist', nil)
	local title =
		mp.get_property_native('metadata/by-key/Title', nil) or
		mp.get_property_native('media-title', nil)
	if artist and title then
		local version = mp.get_property_native('metadata/by-key/Version', nil)
		return table.concat({
			Osd.ass_escape(artist),
			' - ',
			'{\\b1}',
			Osd.ass_escape(title),
			'{\\b0}',
			version and ' (',
			version and Osd.ass_escape(version),
			version and ')',
		})
	else
		local current = mp.get_property_native(
			'playlist/' .. mp.get_property_native('playlist-pos')
		)
		if
			current and
			title == current.filename:gsub('^.*/', '')
		then
			return get_playlist_entry(current)
		else
			return Osd.ass_escape(title)
		end
	end
end

local function flush_cache()
	cache = {}
end

return {
	get_playlist_entry=get_playlist_entry,
	get_current=get_current,
	flush_cache=flush_cache,
}
