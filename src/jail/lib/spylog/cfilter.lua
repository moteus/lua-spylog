local ut = require "lluv.utils"

local function append(t, v)
  t[#t + 1] = v
  return t
end

local CaptureFilter = ut.class() do

function CaptureFilter:__init(t)
  self._filters = {}

  if type(t[1]) ~= 'table' then t = {t} end

  for i = 1, #t do
    local filter = t[i]

    local name = assert(filter[1], string.format('no name for pre filter #%d', i))

    name = (string.sub(name, 1, 1) == '@') and string.sub(name, 2) or ("spylog.cfilter." .. name)
    local Filter = require (name)

    append(self._filters, assert(Filter.new(filter)))
  end

  return self
end

function CaptureFilter:apply(capture)
  for i = 1, #self._filters do
    local filter = self._filters[i]
    if not filter:apply(capture) then
      return false, filter:name()
    end
  end
  return true
end

function CaptureFilter:filter_names()
  local ret = {} for i = 1, #self._filters do
    append(ret, self._filters[i]:name())
  end
  return ret
end

end

return CaptureFilter