local log        = require "spylog.log"
local ut         = require "lluv.utils"
local BaseFilter = require "spylog.prefilter.base"
local iputil     = require "spylog.iputil"

local AclFilter = ut.class(BaseFilter) do

function AclFilter:__init(filter)
  local cidr = assert(filter.cidr, 'prefilter with type `acl` has no cidr list')

  filter.value = filter.value or 'host'
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