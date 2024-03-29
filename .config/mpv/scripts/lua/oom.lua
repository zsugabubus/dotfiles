local utils = require('mp.utils')
local pid = utils.getpid()

local function oom_score_adj(n)
	local path = ('/proc/%d/%s'):format(pid, 'oom_score_adj')
	local f, err = io.open(path, 'wb')
	if not f then
		mp.msg.error(err)
		return
	end
	assert(f:write(tostring(n)))
	assert(f:close())
end

oom_score_adj(900)
