local SERVICE     = require "LuaService"
local config      = require "spylog.config"
config.LOG.prefix = "[filter] "
-------------------------------------------------

local log           = require "spylog.log"
local uv            = require "lluv"
local zthreads      = require "lzmq.threads"
local ztimer        = require "lzmq.timer"
local cjson         = require "cjson.safe"
local stp           = require "StackTracePlus"
local regex         = require "spylog.filter.regex"
local FilterManager = require "spylog.filter.manager"
local exit          = require "spylog.exit"
local CaptureFilter = require "spylog.cfilter"

local pub, err = zthreads.context():socket("PUB", {
  [config.CONNECTIONS.FILTER.JAIL.type] = config.CONNECTIONS.FILTER.JAIL.address
})

if not pub then
  log.fatal("Can not start filter interface: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

log.debug("config.LOG.multithread: %s", tostring(config.LOG.multithread))

local function jail(filter, capture)

  if filter.cfilter then 
    local ok, cfilter_name = filter.cfilter:apply(capture)
    if not ok then
      log.debug("[%s] excluded by capture filter %s", filter.name, cfilter_name)
      return
    end
  end

  local msg, err = cjson.encode(capture)

  if not msg then
    log.alert("Can not encode msg: %s", tostring(err))
    return
  end

  log.trace(msg)

  pub:send(msg)
end

local function init_service()
  local filters = FilterManager.new()

  for i = 1, #config.FILTERS do
    local filter = config.FILTERS[i]
    if filter.enabled then
      filter.name  = filter.name or filter[1]
      filter.match = regex(filter)

      assert(type(filter.name) == 'string', 'invalid filter name')
      assert(filter.source, string.format('filter `%s` has no source', filter.name))

      if filter.cfilter then
        local ok, cfilter= pcall(CaptureFilter.new, filter.cfilter)
        if not ok then 
          local err = string.format('can not build capture filter `%s`: %s', filter.name, cfilter)
          return nil, err
        end

        local names = cfilter:filter_names()
        if #names == 0 then filter.cfilter = nil else
          filter.cfilter = cfilter
          for i = 1, #names do
            log.info('[%s] add capture filter `%s`', filter.name, names[i])
          end
        end
      end

      filters:add(filter)
    end
  end

  if 0 == filters:start(jail) then
    log.warning("there no active filters")
  end
end

local ok, err = pcall(init_service)

if not ok then
  log.fatal(err)
  ztimer.sleep(500)
  return SERVICE.exit()
end

log.info("Service start")

exit.start_monitor(...)

local ok, err = pcall(uv.run, stp.stacktrace)

if not ok then
  log.alert(err)
end

log.info("Service stopped")

ztimer.sleep(500)

SERVICE.exit()
