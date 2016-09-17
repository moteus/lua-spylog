local SERVICE     = require "LuaService"
local config      = require "spylog.config"
config.LOG.prefix = "[filter] "
-------------------------------------------------

local log       = require "spylog.log"
local uv        = require "lluv"
local ut        = require "lluv.utils"
local zthreads  = require "lzmq.threads"
local ztimer    = require "lzmq.timer"
local cjson     = require "cjson.safe"
local path      = require "path"
local stp       = require "StackTracePlus"
local filterrex = require "spylog.filter"
local exit      = require "spylog.exit"

local function build_filters(t)
  for i = 1, #t do
    local filter = t[i]
    filter.name = filter.name or t[i][1]
    filter.match = filterrex(filter)
    local source = filter.source

    if type(source) == 'string' then
      source = config.SOURCES and config.SOURCES[source] or source
    end

    filter.source = source

    if type(source) == 'table' then
      source = source[1]
    end

    assert(type(source) == 'string', "source required")

    local typ, src = ut.split_first(source, ':', true)

    if typ == 'file' then
      src = path.fullpath(src)
      source = typ..":"..src
      if type(filter.source) == 'table' then
        filter.source[1] = source
      else
        filter.source = source
      end
    elseif typ == 'trap' then
      if type(filter.trap) ~= 'table' then
        filter.trap = {[filter.trap] = true}
      else
        for i =1, #filter.trap do
          filter.trap[filter.trap[i]] = true
        end
      end
    end
  end
  return t
end

local ok, FILTERS = pcall(build_filters, config.FILTERS)
if not ok then
  log.fatal("Can not build filter: %s", tostring(FILTERS))
  ztimer.sleep(500)
  return SERVICE.exit()
end

local pub, err = zthreads.context():socket("PUB", {
  [config.CONNECTIONS.FILTER.JAIL.type] = config.CONNECTIONS.FILTER.JAIL.address
})

if not pub then
  log.fatal("Can not start filter interface: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

log.info("Service start")

log.debug("config.LOG.multithread: %s", tostring(config.LOG.multithread))

local function jail(filter, capture)
  local msg, err = cjson.encode(capture)

  if not msg then
    log.alert("Can not encode msg: %s", tostring(err))
    return
  end

  log.trace(msg)

  pub:send(msg)
end

local function apply_filter(filters, filter, ...)
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

local function add_monitor(filters, typ, src, opt)
  local m = require ("spylog.monitor." .. typ)
  m.monitor(src, opt, function(...)
    apply_filter(filters, m.filter, ...)
  end)
end

local function init_service()
  local sources = {}
  for i = 1, #FILTERS do
    local filter = FILTERS[i]
    if filter.enabled then
      local source = filter.source
      if type(source) == 'table' then
        source = source[1]
      end

      local typ, src = ut.split_first(source, ':', true)

      local monitor = sources[source]
      if not monitor then
        log.info("Start new monitor for `%s`", source)
        local FILTER = {}
        monitor = {FILTER = FILTER}
        sources[source] = monitor
        local opt = (type(filter.source) == 'table') and filter.source or nil
        add_monitor(FILTER, typ, src, opt)
      end

      log.info("Add `%s` filter for `%s`", filter.name, source)
      monitor.FILTER[#monitor.FILTER + 1] = filter
    end
  end

  if not next(sources) then
    log.warning("there no active filters")
  end
end

local ok, err = pcall(init_service)

if not ok then
  log.fatal(err)
  ztimer.sleep(500)
  return SERVICE.exit()
end

exit.start_monitor(...)

local ok, err = pcall(uv.run, stp.stacktrace)

if not ok then
  log.alert(err)
end

log.info("Service stopped")

ztimer.sleep(500)

SERVICE.exit()
