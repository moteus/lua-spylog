local uv      = require "lluv"
local spawn   = require "spylog.spawn"
local Args    = require "spylog.args"
local log     = require "spylog.log"
local var     = require "spylog.var"

return function(task, cb)
  local action, options = task.action, task.options
  local context, command = action, action.cmd
  local parameters = action.parameters or command.parameters

  if action.parameters then context = var.combine{action, action.parameters, command.parameters}
  elseif command.parameters then context = var.combine{action, command.parameters} end

  local log_header = string.format("[%s][%s][%s]", action.jail, action.action, task.type)

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

  if (not cmd) or (string.sub(cmd, 1, 1) == '@') then
    cmd = table.remove(args, 1)
  end

  log.debug("%s prepare to execute: %s %s", log_header, cmd, Args.build(args))

  spawn(cmd, args, options.timeout, function(typ, err, status, signal)
    if typ == 'exit' then
      if (not err) and (status ~= 0) then
        err = ("status: %d"):format(status)
      end
      return uv.defer(cb, task, status == 0, err)
    end
    return log.trace("%s command output: [%s] %s", log_header, typ, tostring(err or status))
  end)
end
