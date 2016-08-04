local config   = require "spylog.config"
local Args     = require "spylog.args"
local log      = require "spylog.log"
local ut       = require "lluv.utils"
local sqlite   = require "sqlite3"
local path     = require "path"
local uuid     = require "uuid"
local date     = require "date"
local json     = require "cjson"

local dt = os.date("%Y-%m-%d %H:%M:%S")
assert(dt == date(dt):fmt("%F %T"))

local combine do

local mt = {
  __index = function(self, k)
    for i = 1, #self do
      if self[i][k] ~= nil then
        return self[i][k]
      end
    end
  end
}

combine = function(t)
  return setmetatable(t, mt)
end

end

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
      "action_cmd  not null," ..
      "action_args not null," ..
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

function ActionDB:_add_command(unique, action, action_type, action_cmd, action_args, options)
  local active_action

  local context, action_name = action, action.action
  if action.parameters then
    context = combine{action, action.parameters}
  end

  if unique then -- control duplicate
    unique = Args.apply_tags(unique, context)
    active_action = self:_find_command(action_type, unique)
  end

  if active_action then
    -- we already have one action in queue so we need only move it on early stage
    local flag = (date(active_action.action_time) > date(action.date))

    log.debug("%s > %s == %s (%s)", active_action.action_time, action.date, flag and 'true' or 'false', action_type)

    if action_type == 'unban' then flag = not flag end

    if flag then
      log.info("Reset time for active action from %s to %s", active_action.action_time, action.date)
      local stmt = assert(self._db:prepare("update actions set action_time=? where action_uuid=?;"))
      assert(stmt:bind(
        action.date,
        active_action.action_uuid
      ))
      assert(stmt:exec())
      stmt:close()
    else
      log.info("Reuse active action at %s", active_action.action_time)
    end

    return
  end

  action_args = Args.apply_tags(action_args or '', context)

  -- not prepared command so we create new one
  local stmt = assert(self._db:prepare(
    "INSERT INTO actions(action_uuid,action_time,action_name,action_jail,action_type,"..
    "action_host,action_cmd,action_args,action_opts,action_full,action_uniq)"..
    "VALUES (?,?,?,?,?,?,?,?,?,?,?)"
  ))

  assert(stmt:bind(
    action.uuid,
    action.date,
    action_name,
    action.jail,
    action_type,
    action.host,
    action_cmd,
    action_args,
    json.encode(options or {}),
    json.encode(action),
    unique
  ))

  log.info("[%s] PREPARE COMMAND: [%s] %s %s", action.jail, action.date, action_cmd, action_args)

  assert(stmt:exec())
  stmt:close()
end

function ActionDB:add(action)
  local action_name = action.action

  local command = config.ACTIONS[action_name]

  if not command then
    log.alert('unknown action %s', action_name)
    return
  end

  if command.on then
    local unique  = command.on.unique  or command.unique
    local options = command.on.options or command.options
    action.uuid = uuid.new()
    action.date = date(action.date):fmt("%F %T")
    action_cmd  = command.on[1]
    action_args = command.on[2]

    self:_add_command(unique, action, 'ban', action_cmd, action_args, options)
  end

  if action.bantime and command.off then
    local unique  = command.off.unique  or command.unique
    local options = command.off.options or command.options
    action.uuid = uuid.new()
    action.date = date(action.date):addseconds(action.bantime):fmt("%F %T")
    action_cmd  = command.off[1]
    action_args = command.off[2]

    self:_add_command(unique, action, 'unban', action_cmd, action_args, options)
  end

  return
end

function ActionDB:next()
  local stmt = assert(self._db:prepare(
    "select action_uuid as uuid, action_time as date, action_name as action, action_jail as jail, " ..
    "action_type as type, action_host as host, action_cmd as cmd, action_args as args, " .. 
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