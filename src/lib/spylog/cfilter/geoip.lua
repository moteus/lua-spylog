local log        = require "spylog.log"
local ut         = require "lluv.utils"
local config     = require "spylog.config"
local BaseFilter = require "spylog.cfilter.base"
local path       = require "path"

local geodb, mmdb = {}

local GeoIPFilter = ut.class(BaseFilter) do

function GeoIPFilter:__init(filter)
  log.warning("geoip capture filter is still in experemental stage")

  mmdb = mmdb or require "mmdb"

  if type(filter.filter) == 'string' then
    filter.filter = {filter.filter}
  end
  local list   = filter.filter
  local dbname = filter.mmdb or "GeoLite2-Country.mmdb";

  assert(type(list) == 'table', 'capture filter with type `geoip` has no country list')

  local db_full_path = dbname
  if not path.isfullpath(db_full_path) then
    db_full_path = path.join(config.CONFIG_DIR, 'data', dbname)
  end
  db_full_path = path.normalize(db_full_path)

  local db
  local ok, err = pcall(function()
    db = geodb[db_full_path] or mmdb.open(db_full_path)
    geodb[db_full_path] = db
  end)

  if not ok then
    error("can not open database file: " .. db_full_path .. "; " .. err)
  end

  local hash = {} for i = 1, #list do
    local value = string.upper(list[i])
    hash[ value ] = true
  end

  self._hash  = hash
  self._mmdb  = db
  self._cache = setmetatable({}, {__mode = "v"})

  filter.capture = filter.capture or 'host'
  self.__base.__init(self, filter)

  return self
end

local function find_country(self, host)
  local ret = self._cache[host]
  if ret then return ret end
  --! @todo support IPv6
  ret = self._mmdb:search_ipv4(host)
  ret = ret and ret.country and ret.country.iso_code or "--"
  self._cache[host] = ret
  return ret
end

function GeoIPFilter:apply(capture)
  local value = self:value(capture)

  if value then
    value = find_country(self, value)

    if value and self._hash[value] then
      return self._allow
    end
  end

  return not self._allow
end

end

return GeoIPFilter