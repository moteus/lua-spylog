local ut         = require "lluv.utils"
local BaseFilter = require "spylog.cfilter.base"

local ListFilter = ut.class(BaseFilter) do

local Class = ListFilter

function ListFilter:__init(filter)
  if type(filter.filter) == 'string' then
    filter.filter = {filter.filter}
  end
  local list = filter.filter

  assert(type(list) == 'table', 'capture filter with type `list` has no list of values')
  assert(filter.capture, 'capture filter with type `list` has no capture name')

  Class.__base.__init(self, filter)

  self._nocase = not not filter.nocase


  local hash = {} for i = 1, #list do
    local value = self._nocase and string.upper(list[i]) or list[i]
    hash[ value ] = true
  end

  self._hash = hash

  return self
end

function ListFilter:apply(capture)
  local value = self:value(capture)

  if value then
    if self._nocase then
      value = string.upper(value)
    end
    if self._hash[value] then
      return self._allow
    end
  end

  return not self._allow
end

end

return ListFilter