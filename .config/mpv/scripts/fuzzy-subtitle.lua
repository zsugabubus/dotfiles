local utils = require 'mp.utils'

mp.register_event('file-loaded', function()
  local filename = mp.get_property('path')
  local dirname, basename = utils.split_path(filename)

  local patterns = {}

  local basename_esc = text2pat(basename)
  table.insert(patterns, basename_esc .. '.srt')
  table.insert(patterns, (string.match(basename_esc, '(.*)%..+') or '') .. '.srt')

  local serno, epno = string.match(basename, '[sS]0*(%d+)[eE]0*(%d+)')
  if serno ~= nil and epno ~= nil then
    table.insert(patterns, '[sS]0*' .. serno .. '[eE]0*' .. epno .. '.*%.srt$')
  end

  for i,subdir in pairs(mp.get_property_native('sub-file-paths')) do
    walk(dirname .. '/' .. subdir, patterns)
  end

  for i,p in pairs(mp.get_property_native('sub-files')) do
  mp.msg.error(p)
  end

end)

function text2pat(text)
  return text:gsub('([^%w])', '%%%1')
end

function walk(path, patterns)
  for i,file in pairs(utils.readdir(path, 'files') or {}) do
    for i,pattern in pairs(patterns) do
      if file:find(pattern) ~= nil then
        mp.commandv('sub-add', file)
      end
    end
  end
  for i,dir in pairs(utils.readdir(path, 'dirs') or {}) do
    walk(path .. '/' .. dir, patterns)
  end
end
