local pid = require('mp.utils').getpid()

local function oom_score_adj(n)
	local path = string.format('/proc/%d/oom_score_adj', pid)
	local f, err = io.open(path, 'wb')
	if not f then
		mp.msg.error(err)
		return
	end
	assert(f:write(tostring(n)))
	assert(f:close())
end

oom_score_adj(900)
