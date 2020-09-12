--[[ function on_changed(_, count)
  mp.command('script-message osc-visibility ' ..
    (count ~= 1 and 'always' or 'auto'))
  if count > 1 then
    mp.unobserve_property(on_changed)
  end
end

mp.observe_property('playlist-count', 'number', on_changed) ]]
