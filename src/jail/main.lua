local SERVICE     = require "LuaService"
local config      = require "spylog.config"
config.LOG.prefix = "[jail] "
-------------------------------------------------

local log           = require "spylog.log"
local version       = require "spylog.version"
local uv            = require "lluv"
uv.poll_zmq         = require "lluv.poll_zmq"
local zthreads      = require "lzmq.threads"
local ztimer        = require "lzmq.timer"
local cjson         = require "cjson.safe"
local Counter       = require "spylog.TimeCounters"
local date          = require "date"
local stp           = require "StackTracePlus"
local exit          = require "spylog.exit"
local var           = require "spylog.var"
local path          = require "path"
local CaptureFilter = require "spylog.cfilter"

local function rndint(v)
  return math.random(0, v)
end

log.info('Starting %s version %s. %s', version._NAME, version._VERSION, version._COPYRIGHT)

local DEFAULT = config.JAIL and config.JAIL.default or {}

local sub, err = zthreads.context():socket("SUB",{
  [config.CONNECTIONS.JAIL.FILTER.type] = config.CONNECTIONS.JAIL.FILTER.address;
  subscribe = "";
})

if not sub then
  log.fatal("Can not start filter interface: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

local pub, err = zthreads.context():socket("PUB",{
  [config.CONNECTIONS.JAIL.ACTION.type] = config.CONNECTIONS.JAIL.ACTION.address;
})

if not pub then
  log.fatal("Can not start action interface: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

local function apply_vars(jail, dst, src, context)
  for i, v in pairs(src) do
    if type(v) == 'table' then
      dst[i] = apply_vars(jail, {}, v, context)
    elseif type(v) == 'string' then
      local unknown
      dst[i], unknown = var.format(v, context)
      if unknown then
        return log.alert("[%s] unknown parameter: %s", jail.name, next(unknown))
      end
    else dst[i] = v end
  end
  return dst
end

local function build_action(jail, action, context)
  if type(action) == 'string' then
    local unknown
    action, unknown = var.format(action, context)
    if unknown then
      return log.alert("[%s] unknown parameter: %s", jail.name, next(unknown))
    end
    return {action}
  end

  local name, unknown, parameters = var.format(action[1], context)
  if unknown then
    return log.alert("[%s] unknown parameter: %s", jail.name, next(unknown))
  end

  if action[2] then
    context.action = name
    parameters = apply_vars(jail, {}, action[2], context)
  end

  return {name, parameters}
end

local function action(jail, filter, value)
  -- extend filter capture
  filter.jail    = jail.name
  filter.bantime = jail.bantime
  filter.counter = value
  if jail.rndtime then
    filter.bantime = filter.bantime + rndint(jail.rndtime)
  end

  -- build jail parameters
  local parameters
  if jail.parameters then
    local context = DEFAULT.parameters and var.combine{filter, DEFAULT.parameters} or filter
    parameters = apply_vars(jail, {}, jail.parameters, context)
  end

  local context
  if parameters then
    context = var.combine{filter, parameters, DEFAULT.parameters}
  elseif DEFAULT.parameters then
    context = var.combine{filter, DEFAULT.parameters}
  else
    context = filter
  end

  local actions = {}
  if type(jail.action) == 'string' then
    local action = build_action(jail, jail.action, context)
    if not action then return end
    actions[1] = action
  else
    for _, action in ipairs(jail.action) do
      action = build_action(jail, action, context)
      if not action then return end
      actions[#actions + 1] = action
    end
  end

  local msg = cjson.encode{
    filter     = filter.filter;
    jail       = filter.jail;
    bantime    = filter.bantime;
    host       = filter.host;
    date       = filter.date;
    action     = actions;
  }

  log.trace("action %s", msg)

  pub:send(msg)
end

log.debug("config.LOG.multithread: %s", tostring(config.LOG.multithread))

log.notice("Connected to filters")

local JAIL do

local function append_jail(jails, filter_name, jail)
  local t = jails[filter_name]

  if not t then
    t = {} 
    jails[filter_name] = t
  end
  t[#t + 1] = jail

  return jails
end

local function j(t)
  local jails = {}
  for i = 1, #t do if t[i].enabled or (t[i].enabled == nil) then
    local jail = t[i]
    jails[#jails + 1] = jail

    jail.name = jail.name or jail[1]
    if type(jail.filter) == 'table' then
      for j = 1, #jail.filter do
        append_jail(jails, jail.filter[j], jail)
      end
    else
      append_jail(jails, jail.filter, jail)
    end

    -- apply default values
    for name, value in pairs(DEFAULT) do
      if name ~= 'parameters' and jail[name] == nil then
        jail[name] = value
      end
    end

    if jail.cfilter then
      local ok, cfilter= pcall(CaptureFilter.new, jail.cfilter)
      if not ok then 
        local err = string.format('can not build capture filter `%s`: %s', jail.name, cfilter)
        return nil, err
      end

      local names = cfilter:filter_names()
      if #names == 0 then jail.cfilter = nil else
        jail.cfilter = cfilter
        for i = 1, #names do
          log.info('[%s] add capture filter `%s`', jail.name, names[i])
        end
      end
    end
  end end

  return jails
end

JAIL, err = j(config.JAILS)

if not JAIL then
  log.fatal("Can not load jails: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

if not next(JAIL) then
  log.warning('there no any active jails')
end

end

local jail_counters = {}

local function create_counter(jail)
  local counter


  counter = Counter.jail:new( jail )
  return counter
end

local function check_jail(jail, capture)
  local banwhat = jail.counter and jail.counter.capture or 'host'
  if not capture[banwhat] then
    log.error('filter `%s` does not provide `%s` capture', capture.filter, banwhat)
    return
  end

  if jail.cfilter then 
    local ok, cfilter_name = jail.cfilter:apply(capture)
    if not ok then
      log.debug("[%s] message from %s excluded by capture filter %s", jail.name, capture.filter, cfilter_name)
      return
    end
  end

  local counter = jail_counters[jail.name]
  if not counter then
    counter = create_counter(jail)
    jail_counters[jail.name] = counter
  end

  local value = counter:inc(capture)

  if value then
    if value >= jail.maxretry then
      counter:reset(capture)
      log.warning("[%s] %s - %d", jail.name, capture[banwhat], value)
      action(jail, capture, value) --! @note `action` may add some fields to `capture`
    else
      log.trace("[%s] %s - %d", jail.name, capture[banwhat], value)
    end
  end
end

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

  local capture = cjson.decode(msg)
  if not (capture and capture.filter and capture.date) then
    log.error("invalid msg: ", msg:sub(128))
    return
  end

  local jails = JAIL[capture.filter]
  if not jails then
    log.warning("unknown jail for filter `%s`", capture.filter)
  else for i = 1, #jails do
    check_jail(jails[i], capture)
  end end
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
      local now = date()
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

for filter, jails in pairs(JAIL) do
  if type(filter) ~= 'number' then
    for i = 1, #jails do
      log.info("Attach filter `%s` to jail `%s`", filter, jails[i].name)
    end
  end
end

local ok, err = pcall(uv.run, stp.stacktrace)

if not ok then
  log.alert(err)
end

log.info("Service stopped")

ztimer.sleep(500)

SERVICE.exit()
