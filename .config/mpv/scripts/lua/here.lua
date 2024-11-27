local utils = require('mp.utils')

local cwd = utils.getcwd()
local mpv_here = os.getenv('XDG_RUNTIME_DIR') .. '/mpv_here'
local path

local function join_url(a, b)
	if string.sub(b, 1, 1) == '/' or string.find(b, '^[a-z]+://') then
		return b
	end
	return a .. '/' .. b
end

local function write()
	if not path then
		return
	end
	local f = io.open(mpv_here, 'w')
	if f then
		assert(f:write(join_url(cwd, path)))
		assert(f:close())
	end
end

mp.observe_property('path', 'native', function(_, x)
	path = x
	write()
end)

mp.observe_property('pause', 'native', function(_, x)
	if not x then
		write()
	end
end)
