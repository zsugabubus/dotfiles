local Osd = require('osd')

local SPACE_PATTERNS = { '%.', '%-', '%_' }

local M = {}

local cache = setmetatable({}, { __mode = 'kv' })

function M.from_playlist_entry(entry)
	local s = cache[entry.filename]
	if s then
		return s
	end

	local s = entry.filename
	s = string.gsub(s, '^./', '')
	s = string.gsub(s, '/.*/', '/\u{2026}/')
	s = string.gsub(s, '([^/])%.[0-9A-Za-z]+$', '%1')

	if not string.find(s, ' ') then
		local n = 0
		for _, pattern in pairs(SPACE_PATTERNS) do
			local x, xn = string.gsub(s, pattern, ' ')
			if xn > n then
				s, n = x, xn
			end
		end
	end

	s = string.gsub(s, ' [0-9]+p[^/]*', '')
	s = string.gsub(s, ' [1-9][0-9][0-9][0-9] [A-Za-z0-9][^/]', '')

	s = Osd.ass_escape_nl(s)
	cache[entry.filename] = s
	return s
end

function M.get_current_ass()
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
		local pos = mp.get_property_native('playlist-pos')
		local current = mp.get_property_native('playlist/' .. pos)
		if
			current and (not title or title == current.filename:gsub('^.*/', ''))
		then
			return M.from_playlist_entry(current)
		elseif title then
			return Osd.ass_escape_nl(title)
		else
			return
		end
	end
end

return M
