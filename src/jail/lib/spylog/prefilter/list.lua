local ut         = require "lluv.utils"
local BaseFilter = require "spylog.prefilter.base"

local ListFilter = ut.class(BaseFilter) do

function ListFilter:__init(filter)
  assert(filter.list, 'prefilter with type `list` has no list of values')
  if type(filter.list) == 'string' then
    filter.list = {filter.list}
  end

  assert(filter.value, 'prefilter with type `list` has no value')

  self.__base.__init(self, filter)

  local hash = {} for i = 1, #filter.list do
    hash[ filter.list[i] ] = true
  end

  self._hash = hash

  return self
end

function ListFilter:apply(capture)
  local value = self:value(capture)

  return value and self._hash[value]
end

end

return ListFilter