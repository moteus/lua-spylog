local ut         = require "lluv.utils"
local BaseFilter = require "spylog.cfilter.base"

local ListFilter = ut.class(BaseFilter) do

function ListFilter:__init(filter)
  assert(filter.list, 'capture filter with type `list` has no list of values')
  if type(filter.list) == 'string' then
    filter.list = {filter.list}
  end

  assert(filter.value, 'capture filter with type `list` has no value')

  self.__base.__init(self, filter)

  self._nocase = not not filter.nocase

  local hash = {} for i = 1, #filter.list do
    hash[ self._nocase and string.upper(filter.list[i]) or filter.list[i] ] = true
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