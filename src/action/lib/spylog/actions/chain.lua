local uv      = require "lluv"
local spawn   = require "spylog.spawn"
local Args    = require "spylog.args"
local var     = require "spylog.var"
local log     = require "spylog.log"

return function(task, cb)
  local action, options = task.action, task.options
  local context, command = action, action.cmd
  local parameters = action.parameters or command.parameters

  if action.parameters then context = var.combine{action, action.parameters, command.parameters}
  elseif command.parameters then context = var.combine{action, command.parameters} end

  local log_header = string.format("[%s][%s][%s]", action.jail, action.action, task.type)

  local commands = command[2]
  if type(commands) == 'string' then commands = {commands} end

  for i = 1, #commands do
    if type(commands[i]) == 'string' then
      commands[i] = {commands[i]}
    end

    local command = commands[i]

    local cmd, command_args
    if command[2] then
      cmd          = command[1]
      command_args = Args.apply_tags(command[2], context)
    else
      command_args = Args.apply_tags(command[1], context)
    end

    local args, tail = Args.split(command_args)

    if not args then
      log.error("%s Can not parse argument string: %q", log_header, command_args)
      return uv.defer(cb, task, false, args)
    end

    if tail then
      log.warning("%s Unused command arguments: %q", log_header, tail)
    end

    if not cmd then cmd = table.remove(args, 1) end

    command[1], command[2] = cmd, args

    log.debug("%s[%d] prepare to execute: %s %s", log_header, i, cmd, Args.build(args))
  end

  local last_error, last_command
  spawn.chain(commands, options.timeout, function(i, typ, err, status, signal)
    if typ == 'done' then
      if not last_command then
        last_error = string.format('nothing to execute')
      end
      return uv.defer(cb, task, not last_error, last_error)
    end

    if typ == 'exit' then
      if (not err) and (status ~= 0) then
        err = ("status: %d"):format(status)
      end
      last_command, last_error, last_status = i, err, status
      log.debug("%s[%d] chain command exit: %s", log_header, i, tostring(err or status))
      return
    end

    return log.trace("%s[%d] chain command output: [%s] %s", log_header, i, typ, tostring(err or status))
  end)
end
