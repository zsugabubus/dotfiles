local default_item

mp.add_key_binding(nil, 'select-filters', function()
	local function toalpha(n)
		local s = ''
		while n > 0 do
			n = n - 1
			s = string.char(97 + (n % 26)) .. s
			n = math.floor(n / 26)
		end
		return s
	end

	local function format_avdict(avdict)
		local t = {}
		for k, v in pairs(avdict) do
			table.insert(t, ('%s=%s'):format(k, v))
		end
		return table.concat(t, ':')
	end

	local function stringify_filter(f)
		local params = f.params.graph and ('[%s]'):format(f.params.graph)
			or format_avdict(f.params)
		return ('%s%s%s'):format(f.name, params == '' and '' or '=', params)
	end

	local function format_filter(t, i, enabled, s)
		return ('%s: %s: %s %s'):format(
			toalpha(i),
			t,
			enabled and '●' or '○',
			s
		)
	end

	local items = {}
	local data = {}

	local defaults = require('utils').read_lua_options('filters.lua') or {}

	local function add(prop, t)
		local enabled = {}
		local seen = {}
		local value = mp.get_property_native(prop)

		for _, f in pairs(value) do
			f.string = stringify_filter(f)
			enabled[f.string] = f.enabled
		end

		for _, f in ipairs(defaults[prop] or {}) do
			table.insert(items, format_filter(t, #items + 1, enabled[f], f))
			table.insert(data, { prop, f })
			seen[f] = true
		end

		for i, f in pairs(value) do
			if not seen[f.string] then
				table.insert(items, format_filter(t, #items + 1, f.enabled, f.string))
				table.insert(data, { prop, f.string })
			end
		end
	end

	add('vf', 'Video')
	add('af', 'Audio')

	require('mp.input').select({
		prompt = 'Select a filter:',
		items = items,
		keep_open = true,
		default_item = default_item,
		default_text = '^',
		select_one = true,
		submit = function(i)
			local item = data[i]
			default_item = i
			mp.commandv(item[1], 'toggle', item[2])
			mp.commandv('script-message', 'select-filters')
		end,
	})
end)
