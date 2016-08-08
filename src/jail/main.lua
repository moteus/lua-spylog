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
local var      = require "spylog.var"
local path     = require "path"
local ok, ptree = pcall(require, "prefix_tree")
if not ok then ptree = nil end

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

local function action(jail, filter)
  -- convert `filter` to message
  filter.filter  = filter.name
  filter.jail    = jail.name
  filter.bantime = jail.bantime
  filter.name    = nil

  -- build jail parameters
  local parameters
  if jail.parameters then
    parameters = {}
    local context = DEFAULT.parameters and var.combine{filter, DEFAULT.parameters} or filter
    for i, v in pairs(jail.parameters) do
      local unknown
      parameters[i], unknown = var.format(v, context)
      if unknown then
        return log.alert("[%s] unknown parameter: %s", jail.name, next(unknown))
      end
    end
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
    local unknown
    actions[1], unknown = var.format(jail.action, context)
    if unknown then
      return log.alert("[%s] unknown parameter: %s", jail.name, next(unknown))
    end
  else
    local unknown
    for _, action in ipairs(jail.action) do
      if type(action) == 'string' then
        actions[#actions + 1], unknown = var.format(action, context)
        if unknown then
          return log.alert("[%s] unknown parameter: %s", jail.name, next(unknown))
        end
      else
        local parameters
        if action[2] then
          parameters = {}
          for name, value in pairs(action[2]) do
            parameters[name], unknown = var.format(value, context)
            if unknown then
              return log.alert("[%s] unknown parameter: %s", jail.name, next(unknown))
            end
          end
        end
        local action_name, unknown = var.format(action[1], context)
        if unknown then
          return log.alert("[%s] unknown parameter: %s", jail.name, next(unknown))
        end
        actions[#actions + 1] = {action_name, parameters}
      end
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

    -- apply default values
    for name, value in pairs(DEFAULT) do
      if name ~= 'parameters' and jail[name] == nil then
        jail[name] = value
      end
    end

    -- load prefixes
    if jail.counter and jail.counter.prefix then
      if not ptree then
        return nil, 'Prefix counter not avaliable'
      end

      local prefixes, tree = jail.counter.prefix

      if type(prefixes) == 'table' then
        tree = ptree.new()
        if prefixes[1] then
          for _, prefix in ipairs(prefixes) do
            tree:add(prefix, '')
          end
        else
          for prefix, value in pairs(prefixes) do
            tree:add(prefix, value)
          end
        end
      else
        local base_prefix_dir = path.join(SERVICE.CONFIG_DIR, 'config', 'jails')
        local full_path = path.fullpath(path.isfullpath(prefixes) or path.join(base_prefix_dir, prefixes))
        log.debug('[%s] full path for prefix: %s', jail.name, full_path)
        if not path.isfile(full_path) then
          return nil, string.format('[%s] can not find prefix file %s', jail.name, full_path)
        end
        local ok
        ok, tree = pcall(ptree.LoadPrefixFromFile, full_path)
        if not ok then return nil, tree end
      end

      jail.counter.prefix = tree
    end

  end
  return t
end

JAIL, err = j(config.JAILS)

if not JAIL then
  log.fatal("Can not load jails: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

end

local jail_counters = {}

local function create_counter(jail)
  local counter

  if jail.counter and jail.counter.prefix then
    counter = Counter.prefix:new( jail )
  end

  if not counter then
    counter = Counter.jail:new( jail )
  end

  return counter
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
      counter = create_counter(jail)
      jail_counters[t.name] = counter
    end

    local value = counter:inc(t)

    if value then
      if value >= jail.maxretry then
        counter:reset(t)
        log.warning("[%s] %s - %d", jail.name, t.host, value)
        action(jail, t) --! @note `action` may add some fields to `t`
      else
        log.trace("[%s] %s - %d", jail.name, t.host, value)
      end
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
