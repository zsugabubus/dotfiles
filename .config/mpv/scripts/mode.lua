return {
	add_key_bindings=function(key_bindings)
		for k,v in pairs(key_bindings) do
			local fn = k
			while type(fn) == 'string' do
				fn = key_bindings[fn]
			end
			mp.add_forced_key_binding(k, k, function(e)
				if e.event == 'down' or e.event == 'repeat' then
					fn()
				end
			end, {complex=true})
		end
	end,
	remove_key_bindings=function(key_bindings)
		for k,v in pairs(key_bindings) do
			mp.remove_key_binding(k)
		end
	end,
}
