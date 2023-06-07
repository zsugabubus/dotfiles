local M = {}
local Osd = require('osd')

local HORIZONTAL_ELLIPSIS = '\u{2026}'
local SP_PATS = { '%.', '-', '%_' }
local HE_PATH = '/' .. HORIZONTAL_ELLIPSIS .. '/'

local cache = {}

local function sub_hex2str(x)
	return string.char(tonumber(x, 16))
end

function M.get_playlist_entry(item)
	local s = cache[item.title]
	if s ~= nil then
		return s
	end

	if item.title ~= nil then
		s = Osd.ass_escape_nl(item.title)
		cache[item.title] = s
		return s
	end

	s = cache[item.filename]
	if s ~= nil then
		return s
	end

	s = item.filename:gsub('^./', '')

	if 80 < #s then
		s = s:gsub('/.*/', HE_PATH)
	end

	local original = s

	-- Encodes a multi-byte character.
	if s:match('_%x%x_%x%x') then
		s = s:gsub('_(%x%x)', sub_hex2str)
	end

	if s == original then
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

	s = Osd.ass_escape_nl(s)

	cache[item.filename] = s
	return s
end

function M.get_current()
	local artist = mp.get_property_native('metadata/by-key/Artist', nil)
	local title = mp.get_property_native('metadata/by-key/Title', nil)
		or mp.get_property_native('media-title', nil)
	if artist and title then
		local version = mp.get_property_native('metadata/by-key/Version', nil)
		return table.concat({
			Osd.ass_escape_nl(artist),
			' - ',
			'{\\b1}',
			Osd.ass_escape_nl(title),
			'{\\b0}',
			version and ' (',
			version and Osd.ass_escape_nl(version),
			version and ')',
		})
	else
		local current = mp.get_property_native(
			'playlist/' .. mp.get_property_native('playlist-pos')
		)
		if
			current and (not title or title == current.filename:gsub('^.*/', ''))
		then
			return M.get_playlist_entry(current)
		elseif title then
			return Osd.ass_escape_nl(title)
		else
			return
		end
	end
end

function M.flush_cache()
	cache = {}
end

return M
