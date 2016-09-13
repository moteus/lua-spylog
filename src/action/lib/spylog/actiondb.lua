local config   = require "spylog.config"
local Args     = require "spylog.args"
local log      = require "spylog.log"
local var      = require "spylog.var"
local ut       = require "lluv.utils"
local sqlite   = require "sqlite3"
local path     = require "path"
local uuid     = require "uuid"
local date     = require "date"
local json     = require "cjson"

local dt = os.date("%Y-%m-%d %H:%M:%S")
assert(dt == date(dt):fmt("%F %T"))

local ActionDB = ut.class() do

function ActionDB:__init(fileName)
  self._fileName = fileName or ":memory:"
  self._db = assert(sqlite.open(self._fileName))
  self:init()
  return self
end

function ActionDB:init()
  assert(self._db:exec(
  "BEGIN TRANSACTION;" ..
    "CREATE TABLE IF NOT EXISTS actions (" ..
      "action_uuid not null," ..
      "action_time not null," ..
      "action_name not null," ..
      "action_jail not null," ..
      "action_type not null," ..
      "action_host not null," ..
      "action_opts not null," ..
      "action_full not null," ..
      "action_uniq     null," ..
      "CONSTRAINT pk_actions PRIMARY KEY(action_uuid)" ..
    ");"  ..
  "END TRANSACTION"))
end

function ActionDB:clear()
  assert(self._db:exec(
  "BEGIN TRANSACTION;" ..
    "DROP TABLE IF EXISTS actions;"  ..
  "END TRANSACTION"))
  self:init()
end

function ActionDB:_find_command(action_type, unique)
  local stmt = assert(self._db:prepare(
    "select action_uuid, action_time " ..
    "from actions "..
    "where action_uniq=? and action_type=? " ..
    "order by action_time " .. ((action_type == 'ban') and "desc " or "asc ") ..
    "limit 1"
  ))
  stmt:bind(
    unique,
    action_type
  )
  local row = stmt:first_row()
  stmt:close()
  return row
end

function ActionDB:_add_command(unique, action, action_type, options)
  local active_action

  local context, action_name = action, action.action
  if action.parameters then
    context = var.combine{action, action.parameters}
  end

  local log_prefix = string.format("[%s][%s][%s]", action.jail, action.action, action_type)

  if unique then -- control duplicate
    unique = Args.apply_tags(unique, context)
    active_action = self:_find_command(action_type, unique)
  end

  if active_action then
    -- we already have one action in queue so we need only move it on early stage
    local flag = (date(active_action.action_time) > date(action.date))

    log.debug("%s %s > %s == %s (%s)", log_prefix, active_action.action_time, action.date, flag and 'true' or 'false', action_type)

    if action_type == 'unban' then flag = not flag end

    if flag then
      log.info("%s reset time for active action from %s to %s", log_prefix, active_action.action_time, action.date)
      local stmt = assert(self._db:prepare("update actions set action_time=? where action_uuid=?;"))
      assert(stmt:bind(
        action.date,
        active_action.action_uuid
      ))
      assert(stmt:exec())
      stmt:close()
    else
      log.info("%s reuse active action at %s", log_prefix, active_action.action_time)
    end

    return
  end

  action_args = Args.apply_tags(action_args or '', context)

  -- not prepared command so we create new one
  local stmt = assert(self._db:prepare(
    "INSERT INTO actions(action_uuid,action_time,action_name,action_jail,action_type,"..
    "action_host,action_opts,action_full,action_uniq)"..
    "VALUES (?,?,?,?,?,?,?,?,?)"
  ))

  assert(stmt:bind(
    action.uuid,
    action.date,
    action_name,
    action.jail,
    action_type,
    action.host,
    json.encode(options or {}),
    json.encode(action),
    unique
  ))

  log.info("%s schedule action at %s", log_prefix, action.date)

  assert(stmt:exec())
  stmt:close()
end

function ActionDB:add(action)
  local action_name = action.action

  local command = config.ACTIONS[action_name]

  if not command then
    log.alert('[%s] unknown action %s', action.jail, action_name)
    return
  end

  if command.ban then
    local unique  = command.ban.unique  or command.unique
    local options = command.ban.options or command.options
    action.uuid = uuid.new()
    action.date = date(action.date):fmt("%F %T")
    action.cmd  = command.ban

    self:_add_command(unique, action, 'ban', options)
  end

  if action.bantime and (action.bantime >= 0) and command.unban then
    local unique  = command.unban.unique  or command.unique
    local options = command.unban.options or command.options
    action.uuid = uuid.new()
    action.date = date(action.date):addseconds(action.bantime):fmt("%F %T")
    action.cmd  = command.unban

    self:_add_command(unique, action, 'unban', options)
  end

  return
end

function ActionDB:next()
  local stmt = assert(self._db:prepare(
    "select action_uuid as uuid, action_time as date, action_name as action, action_jail as jail, " ..
    "action_type as type, action_host as host, " .. 
    "action_opts as options, action_full as action " ..
    "from actions "..
    "where action_time<=? " .. 
    "order by action_time " ..
    "limit 1"
  ))
  stmt:bind(os.date("%Y-%m-%d %H:%M:%S"))
  local row = stmt:first_row()
  stmt:close()

  if row then
    row.options = json.decode(row.options)
    row.action  = json.decode(row.action)
  end

  return row
end

function ActionDB:remove(row)
  return self._db:exec(
     "delete from actions "..
     "where action_uuid='" .. row.uuid .. "'"
  )
end

function ActionDB:close()
  self.db:close()
end

end

--[=[
do
local pp = require "pp"

local db = ActionDB.new()
local action1 = cjson.decode[[{"host":"192.168.123.102","action":"ipsec","jail":"freeswitch-auth-request","date":"2015-09-17 13:36:15.626250","bantime":60,"filter":"freeswitch-auth-request"}]]
local action2 = cjson.decode[[{"host":"192.168.123.102","action":"ipsec","jail":"freeswitch-auth-request","date":"2015-09-17 12:36:15.626250","bantime":10800,"filter":"freeswitch-auth-request"}]]
local action3 = cjson.decode[[{"host":"192.168.123.102","action":"ipsec","jail":"freeswitch-auth-request","date":"2015-09-17 14:36:15.626250","bantime":60,"filter":"freeswitch-auth-request"}]]

db:add(action1)
db:add(action2)
db:add(action3)

print("-------------------------------------------------")

local row = db:next()
while row do 
  pp(row)
  db:remove(row)
  row = db:next()
end

return

end

--]=]

return ActionDB