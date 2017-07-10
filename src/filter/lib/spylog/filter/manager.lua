local config   = require "spylog.config"
local log      = require "spylog.log"
local path     = require "path"
local uv       = require "lluv"
local ut       = require "lluv.utils"
local EventLog = require "spylog.eventlog"

local function append(t, v)
  t[#t + 1] = v
  return t
end

local Source = ut.class() do

local function apply_filter(jail, filters, filter, ...)
  for i = 1, #filters do
    local capture = filter(filters[i], ...)
    if capture then
      jail(filters[i], capture)
      if filters[i].stop then
        break
      end
    end
  end
end

-- @static
function Source.decode_source(source)
  local source_name
  if type(source) == 'string' then
    source_name = config.SOURCES and config.SOURCES[source] and source
    source = config.SOURCES and config.SOURCES[source] or source
  end

  local source_string = (type(source) == 'table') and source[1] or source

  assert(type(source_string) == 'string', "source string required")

  local source_type, source_info = ut.split_first(source_string, ':', true)

  assert(source_info, string.format('invalid source string: %s', source_string))

  if source_type == 'file' then
    source_info   = path.fullpath(source_info)
    source_string = source_type..":"..source_info
    if type(source) == 'table' then source[1] = source_string end
  end

  source_name = source_name or source_string

  return source_name, source_string, source_type, source_info, (type(source) == 'table') and source or nil
end

function Source:__init(source)
  local source_name, source_string, source_type, source_info, source_opt = Source.decode_source(source)

  if source_name == source_string then
    log.info("create new source: %s", source_name)
  else
    log.info("create new source: %s/%s", source_name, source_string)
  end

  self._name    = source_name
  self._string  = source_string
  self._type    = source_type
  self._info    = source_info
  self._opt     = source_opt
  if self._opt then
    self._opt.__name = source_name
    self._opt.__type = source_type
  end
  self._filters = {}

  return self
end

function Source:start(jail)
  if not self._m then
    log.info("start source monitor for: `%s`", self._string)

    local m = require ("spylog.monitor." .. self._type)
    local filters = self._filters
    m.monitor(self._info, self._opt, function(...)
      apply_filter(jail, filters, m.filter, ...)
    end)

    self._m = m
  end
end

function Source:add(filter)
  if self._type == 'trap' then
    if type(filter.trap) ~= 'table' then
      filter.trap = {[filter.trap] = true}
    else
      for i =1, #filter.trap do
        filter.trap[filter.trap[i]] = true
      end
    end
  end

  if self._type == 'eventlog' then
    assert(type(filter.events) == 'table', 'No events list for eventlog filter')
    filter.events = EventLog.BuildFilter(filter.events)
  end

  log.info("attach filter `%s` to source `%s`", filter.name, self._name)

  append(self._filters, filter)
end

end

local FilterManager = ut.class() do

function FilterManager:__init()
  self._sources = {}

  return self
end

function FilterManager:source(filter)
  local source_name = Source.decode_source(filter.source)

  local s = self._sources[source_name]
  if not s then
    s = Source.new(filter.source)
    self._sources[source_name] = s
  end

  return s
end

function FilterManager:add(filter)
  local source = self:source(filter)
  source:add(filter)
  return self
end

function FilterManager:start(jail)
  local n = 0
  for _, source in pairs(self._sources) do
    source:start(jail)
    n = n + 1
  end
  return n
end

end

return FilterManager