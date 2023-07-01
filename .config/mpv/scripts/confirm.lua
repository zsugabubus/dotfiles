-- Emulate [profile].
local ENV
do
	local MAGIC = {
		__index = function(self, name)
			name = string.gsub(name, '_', '-')
			return mp.get_property_native(name)
		end,
	}

	ENV = setmetatable({
		p = setmetatable({}, MAGIC),
		get = function(name, def)
			return mp.get_property_native(name, def)
		end,
	}, MAGIC)
end

local function confirm_if(cond, ...)
	local argv = {...}

	local f = load('return (' .. cond .. ')')
	setfenv(f, ENV)

	local ok, show_confirm = pcall(f)
	if not ok then
		mp.msg.error(show_confirm)
		return
	end

	local function exec()
		mp.commandv(unpack(argv))
	end

	if show_confirm then
		local BINDINGS

		local function no()
			mp.osd_message('')
			for key in pairs(BINDINGS) do
				mp.remove_key_binding(key)
			end
		end

		local function yes()
			exec()
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

		mp.osd_message(string.format('Confirm %s? [Y/n]', argv[1]), 999999)
		for key, fn in pairs(BINDINGS) do
			mp.add_forced_key_binding(key, key, fn)
		end
	else
		exec()
	end
end

local function confirm(...)
	confirm_if('true', ...)
end

-- q script-message-to confirm confirm quit
mp.register_script_message('confirm', confirm)

-- q script-message confirm-if "600 < demuxer_cache_duration or demuxer_via_network" quit
mp.register_script_message('confirm-if', confirm_if)
