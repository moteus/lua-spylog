local log        = require "spylog.log"
local ut         = require "lluv.utils"
local config     = require "spylog.config"
local BaseFilter = require "spylog.cfilter.base"
local path       = require "path"
local mmdb       = require "mmdb"
local lru do local ok
ok, lru = pcall(require, "lru")
if not ok then lru = nil end
end

local geodb = {}
local geodb_cache = {}

local GeoIPFilter = ut.class(BaseFilter) do

local dummy = { country = { iso_code = "--" }, continent = { code = "--" } }

local function find(self, host)
  local ok, ret

  if string.find(host, ':', nil, true) then
    ok, ret = pcall(self._mmdb.search_ipv6, self._mmdb, host)
  else
    ok, ret = pcall(self._mmdb.search_ipv4, self._mmdb, host)
  end

  if not ok then return nil, ret end

  return ret or dummy
end

local function find_with_cache(self, host)
  local ret, err = self._cache:get(host)
  if ret then return ret end
  ret, err = find(self, host)
  self._cache:set(host, ret)

  return ret
end

function GeoIPFilter:__init(filter)
  log.warning("geoip capture filter is still in experemental stage")

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

  local country = {} for i = 1, #list do
    local value = string.upper(list[i])
    country[ value ] = true
  end

  local continent = {}
  if list.continent then 
    if type(list.continent) == 'string' then
      list.continent = {list.continent}
    end

    for i = 1, #list.continent do
      local value = string.upper(list.continent[i])
      continent[ value ] = true
    end
  end

  self._hash  = {continent = continent, country = country}
  self._mmdb  = db

  if filter.cache then
    if not lru then
      log.warning('can not use cache for geoip module. Please install `lua-lru` module.')
    else
      assert(type(filter.cache) == 'number', 'cache elment for geoip filter should be a number')
      local t = geodb_cache[db_full_path] or {}
      geodb_cache[db_full_path] = t
      local cache = t[filter.cache] or lru.new(filter.cache)
      t[filter.cache] = cache
      self._cache = cache
    end
  end

  self._find = self._cache and find_with_cache or find

  filter.capture = filter.capture or 'host'
  self.__base.__init(self, filter)

  return self
end

function GeoIPFilter:apply(capture)
  local value = self:value(capture)

  if value then
    local info, err = self:_find(value)
    if err then
      log.warning("error while search IP: `%s` - %s", value, err)
      -- deny in any case
      return false
    end
    local country = info and info.country and info.country.iso_code
    if country and self._hash.country[country] then
      return self._allow
    end
    local continent = info and info.continent and info.continent.code
    if continent and self._hash.continent[continent] then
      return self._allow
    end
  end

  return not self._allow
end

end

return GeoIPFilter