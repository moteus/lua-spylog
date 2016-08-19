local SERVICE     = require "lib/SERVICE"
local config      = require "spylog.config"
config.LOG.prefix = "[action] "
-------------------------------------------------

local log      = require "spylog.log"
local uv       = require "lluv"
uv.poll_zmq    = require "lluv.poll_zmq"
local zthreads = require "lzmq.threads"
local ztimer   = require "lzmq.timer"
local ut       = require "lluv.utils"
local path     = require "path"
local cjson    = require "cjson.safe"
local stp      = require "StackTracePlus"
local ActionDB = require "spylog.actiondb"
local spawn    = require "spylog.actions.spawn"
local Args     = require "spylog.args"
local exit     = require "spylog.exit"

log.debug("config.LOG.multithread: %s", tostring(config.LOG.multithread))

local EXICUTERS = {}

local db_path = path.normalize(path.join(SERVICE.PATH, "data"))
path.mkdir(db_path)

local actions = ActionDB.new(
  path.join(db_path, "action.db")
)

local ACTION_POLL, action_timer = 10000

local sub, err = zthreads.context():socket("SUB",{
  [config.CONNECTIONS.ACTION.JAIL.type] = config.CONNECTIONS.ACTION.JAIL.address;
  subscribe = "";
})

if not sub then
  log.fatal("Can not start action interface: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

local function do_action(action, cb)
  local cmd  = action.cmd

  log.warning("[%s] EXECUTE COMMAND: [%s] %s %s", action.jail, action.date, action.cmd, action.args)

  local exicuter
  if cmd:sub(1, 1) == '@' then
    exicuter = EXICUTERS[cmd]
    if not exicuter then
      log.alert("Action module not loaded `%s` - %s", action.action.action, cmd:sub(2))
      actions:remove(action)
      return uv.defer(cb)
    end
  else
    exicuter = spawn
  end

  exicuter(action, function(action, ok, err)
    actions:remove(action)
    uv.defer(cb)

    if not ok then
      log.error('[%s] EXECUTE COMMAND error: %s', action.jail, tostring(err or 'unknown'))
    else
      log.info('[%s] EXECUTE COMMAND success', action.jail)
    end
  end)
end

local function next_action()
  local action = actions:next()
  if not action then
    return action_timer:again(ACTION_POLL)
  end

  do_action(action, next_action)
end

uv.poll_zmq(sub):start(function(handle, err, pipe)
  if err then
    log.fatal("poll: %s", tostring(err))
    return uv.stop()
  end

  local msg, err = sub:recvx()
  if not msg then
    if err:name() ~= 'EAGAIN' then
      log.fatal("recv msg: %s", tostring(err))
      uv.stop()
    end
    return
  end

  log.trace("%s", msg)

  local task = cjson.decode(msg)
  if not (task and task.action and task.date) then
    log.error("invalid msg: %q", msg:sub(128))
    return
  end

  if type(task.action) ~= 'table' then
    log.error("invalid action format: %q", msg:sub(128))
    return
  end

  local task_actions = task.action
  for i = 1, #task_actions do
    local action = task_actions[i]
    if type(action) ~= 'table' then
      log.error("invalid action format: %q", msg:sub(128))
      return
    end
  end

  -- ugly hack. `actions.add` method change date field.
  -- so we have reset this field each time
  local date = task.date

  for i = 1, #task_actions do
    local action = task_actions[i]

    -- build task table to each action
    task.date       = date
    task.action     = action[1]
    task.parameters = action[2]
    actions:add(task)
  end

  if action_timer:active() then
    action_timer:again(1)
  end
end)

action_timer = uv.timer():start(0, ACTION_POLL, function()
  action_timer:stop()
  next_action()
end)

exit.start_monitor(...)

local function init_service()

  local function append_executer(cmd)
    if cmd:sub(1, 1) == '@' and not EXICUTERS[cmd] then
      local ok, executer = pcall(require, (cmd:sub(2)))
      assert(ok, ("Can not load action module `%s`: %s"):format(cmd:sub(2), tostring(executer)))
      EXICUTERS[cmd] = executer
    end
  end

  for name, cmd in pairs(config.ACTIONS) do
    if cmd.ban   then append_executer(cmd.ban[1])   end
    if cmd.unban then append_executer(cmd.unban[1]) end
    log.info("Add new action: %s", tostring(name))
  end

end

local ok, err = pcall(init_service)
if not ok then
  log.fatal("Can not load actions: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

local ok, err = pcall(uv.run, stp.stacktrace)

if not ok then
  log.alert(err)
end

log.info("Service stopped")

ztimer.sleep(500)

SERVICE.exit()
