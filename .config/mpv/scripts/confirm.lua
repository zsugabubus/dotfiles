-- Emulate [profile].
local PROPERTY_MT = {
	__index = function(self, property)
		property = property:gsub('_', '-')
		return mp.get_property_native(property)
	end
}

local ENV = {
	p = {}
}
setmetatable(ENV.p, PROPERTY_MT)
setmetatable(ENV, PROPERTY_MT)

local function confirm_if(cond, ...)
	local argv = {...}
	local BINDINGS

	local function no()
		mp.osd_message('')
		for key in pairs(BINDINGS) do
			mp.remove_key_binding(key)
		end
	end

	local function yes()
		mp.commandv(unpack(argv))
		no()
	end

	BINDINGS = {
		y = yes,
		Y = yes,
		Enter = yes,
		n = no,
		N = no,
		Esc = no,
	}

	local f = load('return (' .. cond .. ')')
	setfenv(f, ENV)
	local show_confirm = f()

	if show_confirm then
		mp.osd_message(('Confirm %s? [Y/n]'):format(
			argv[1]
		), 999999)
		for key, fn in pairs(BINDINGS) do
			mp.add_forced_key_binding(key, key, fn)
		end
	else
		yes()
	end
end

local function confirm(...)
	confirm_if('true', ...)
end

-- q script-message-to confirm confirm quit
mp.register_script_message('confirm', confirm)

-- q script-message confirm-if "600 < demuxer_cache_duration or demuxer_via_network" quit
mp.register_script_message('confirm-if', confirm_if)
