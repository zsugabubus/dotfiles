local utils = require('mp.utils')

local cwd = utils.getcwd()
local mpv_here = os.getenv('XDG_RUNTIME_DIR') .. '/mpv_here'

local function join_url(a, b)
	if string.sub(b, 1, 1) == '/' or string.find(b, '^[a-z]+://') then
		return b
	end
	return a .. '/' .. b
end

mp.observe_property('path', 'native', function(_, path)
	if not path then
		return
	end

	local f = io.open(mpv_here, 'w')
	if not f then
		return
	end

	assert(f:write(join_url(cwd, path)))
	assert(f:close())
end)
