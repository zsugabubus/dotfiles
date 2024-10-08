local Osd = require('osd')

local SPACE_PATTERNS = { '%.', '%-', '%_' }

local M = {}

local cwd = require('mp.utils').getcwd() .. '/'
local filename_to_title = setmetatable({}, {
	__mode = 'kv',
	__index = function(t, k)
		local s = k

		if string.sub(s, 1, 2) == './' then
			s = string.sub(s, 3)
		elseif string.sub(s, 1, #cwd) == cwd then
			s = string.sub(s, #cwd + 1)
		end

		s = string.gsub(s, '([^/])%.[0-9A-Za-z]+$', '%1')

		if not string.find(s, ' ', 1, true) then
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

		s = Osd.esc(s)
		t[k] = s
		return s
	end,
})

function M.from_playlist_entry(entry)
	return filename_to_title[entry.filename]
end

function M.get_current_ass()
	local artist = mp.get_property_native('metadata/by-key/Artist', nil)
	local title = mp.get_property_native('metadata/by-key/Title', nil)
		or mp.get_property_native('media-title', nil)

	if artist and title then
		local version = mp.get_property_native('metadata/by-key/Version', nil)
		return table.concat({
			Osd.esc(artist),
			' - ',
			'{\\b1}',
			Osd.esc(title),
			'{\\b0}',
			version and ' (',
			version and Osd.esc(version),
			version and ')',
		})
	end

	local pos = mp.get_property_native('playlist-pos')
	local current = mp.get_property_native('playlist/' .. pos)

	if current and (not title or title == current.filename:gsub('^.*/', '')) then
		return M.from_playlist_entry(current)
	elseif title then
		return Osd.esc(title)
	else
		return
	end
end

return M
