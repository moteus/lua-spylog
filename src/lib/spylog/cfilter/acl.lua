local log        = require "spylog.log"
local ut         = require "lluv.utils"
local BaseFilter = require "spylog.cfilter.base"
local iputil     = require "spylog.iputil"

local AclFilter = ut.class(BaseFilter) do

function AclFilter:__init(filter)
  if type(filter.filter) == 'string' then
    filter.filter = {filter.filter}
  end
  local cidr = filter.filter
  
  assert(type(cidr) == 'table', 'capture filter with type `acl` has no cidr list')

  filter.capture = filter.capture or 'host'
  self.__base.__init(self, filter)

  self._cidr = iputil.load_cidrs(cidr)

  return self
end

function AclFilter:apply(capture)
  local value = self:value(capture)

  if value and iputil.find_cidr(value, self._cidr) then
    return self._allow
  end

  return not self._allow
end

end

return AclFilter