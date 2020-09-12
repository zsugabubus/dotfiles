local first = true
mp.observe_property('fullscreen', 'string', function(_, fullscreen)
  if first then
    first = false
    if fullscreen == 'no' then
      return
    end
  end
  mp.osd_message('Fullscreen: ' .. fullscreen)
end)
