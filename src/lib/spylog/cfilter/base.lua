local log        = require "spylog.log"
local ut         = require "lluv.utils"

local BaseFilter = ut.class() do

function BaseFilter:__init(filter)
  self._name  = filter[1]
  self._vname = filter.value
  self._allow = filter.type == 'allow'
  return self
end

function BaseFilter:value(capture)
  local value = capture[self._vname]
  if not value then
    log.warning('filter %s has no capture %s', capture.filter, vname)
  end
  return value
end

function BaseFilter:name()
  return self._name
end

end

return BaseFilter