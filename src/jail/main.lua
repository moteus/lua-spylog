local SERVICE     = require "lib/SERVICE"
local config      = require "spylog.config"
config.LOG.prefix = "[jail] "
-------------------------------------------------

local log      = require "spylog.log"
local uv       = require "lluv"
uv.poll_zmq    = require "lluv.poll_zmq"
local zthreads = require "lzmq.threads"
local ztimer   = require "lzmq.timer"
local cjson    = require "cjson.safe"
local Counter  = require "spylog.TimeCounters"
local date     = require "date"
local stp      = require "StackTracePlus"
local exit     = require "spylog.exit"

local date_to_ts do

local begin_time = date(2000, 1, 1)

date_to_ts = function (d)
  return math.floor(date.diff(d, begin_time):spanseconds())
end

end

local sub = zthreads.context():socket("SUB",{
  [config.CONNECTIONS.JAIL.FILTER.type] = config.CONNECTIONS.JAIL.FILTER.address;
  subscribe = "";
})

if not sub then
  log.fatal("Can not start filter interface: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

local pub = zthreads.context():socket("PUB",{
  [config.CONNECTIONS.JAIL.ACTION.type] = config.CONNECTIONS.JAIL.ACTION.address;
})

if not pub then
  log.fatal("Can not start action interface: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

local function action(jail, filter)
  local msg = cjson.encode{
    date    = filter.date;
    jail    = jail.name;
    filter  = filter.name;
    host    = filter.host;
    bantime = jail.bantime;
    action  = jail.action;
  }

  log.trace("action %s", msg)

  pub:send(msg)
end

log.debug("config.LOG.multithread: %s", tostring(config.LOG.multithread))

log.notice("Connected to filters")

local JAIL do

local function j(t)
  for i = 1, #t do
    local jail = t[i]
    jail.name = jail.name or jail[1]
    if type(jail.filter) == 'table' then
      for j = 1, #jail.filter do
        t[ jail.filter[j] ] = jail
      end
    else
      t[ jail.filter ] = jail
    end
  end
  return t
end

JAIL = j(config.JAILS)

end

local jail_counters = {}

uv.poll_zmq(sub):start(function(handle, err, pipe)
  if err then
    log.fatal("poll: ", err)
    return uv.stop()
  end

  local msg, err = sub:recvx()
  if not msg then
    if err:name() ~= 'EAGAIN' then
      log.fatal("recv msg: ", err)
      uv.stop()
    end
    return
  end

  log.trace("%s", msg)

  local t = cjson.decode(msg)
  if not (t and t.name and t.date and t.host) then
    log.error("invalid msg: ", msg:sub(128))
    return
  end

  local jail = JAIL[t.name]
  if not jail then
    log.warning("unknown jail for filter `%s`", t.name)
  else
    local counter = jail_counters[t.name]
    if not counter then
      counter = Counter.map:new( Counter.external, jail.findtime )
      jail_counters[t.name] = counter
    end

    local value = counter:inc(t.host, date_to_ts(t.date))

    if value >= jail.maxretry then
      counter:reset(t.host, date_to_ts(t.date))
      log.warning("[%s] %s - %d", jail.name, t.host, value)
      action(jail, t)
    else
      log.trace("[%s] %s - %d", jail.name, t.host, value)
    end
  end
end)

if config.JAIL and config.JAIL.purge_interval then
  local LVL_TRACE = require "log".LVL.TRACE
  local purge_counter  = 0
  local purge_interval = config.JAIL.purge_interval
  log.info("Start purge timer %d [min]", purge_interval)
  uv.timer():start(60000, 60000, function()
    purge_counter = purge_counter + 1
    if purge_counter >= purge_interval then
      purge_counter = 0
      local now = date_to_ts(date())
      for name, jail_counter in pairs(jail_counters) do
        local c
        if log.lvl() >= LVL_TRACE then
          c = jail_counter:count()
        end
        jail_counter:purge(now)
        if c then
          log.trace("Purge jail %s %d => %d", name, c, jail_counter:count())
        end
      end
    end
  end)
end

exit.start_monitor(...)

for filter, jail in pairs(JAIL) do
  if type(filter) ~= 'number' then
    log.info("Attach filter `%s` to jail `%s`", filter, jail.name)
  end
end

local ok, err = pcall(uv.run, stp.stacktrace)

if not ok then
  log.alert(err)
end

log.info("Service stopped")

ztimer.sleep(500)

SERVICE.exit()
