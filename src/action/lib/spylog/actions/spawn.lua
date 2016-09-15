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

  local cmd, args, tail = Args.decode_command(command, context)

  if not cmd then
    log.error("%s Can not parse argument string: %s", log_header, args)
    return uv.defer(cb, task, false, args)
  end

  if tail then
    log.warning("%s Unused command arguments: %q", log_header, tail)
  end

  if string.sub(cmd, 1, 1) == '@' then
    cmd = table.remove(args, 1)
  end

  log.debug("%s prepare to execute: %s %s", log_header, cmd, Args.build(args))

  spawn(cmd, args, options.timeout, function(typ, err, status, signal)
    if typ == 'exit' then
      if not err then
        if not (command.ignore_status or status == 0) then
          err = spawn.estatus(status, signal)
        end
      end
      return uv.defer(cb, task, not err, err)
    end
    return log.trace("%s command output: [%s] %s", log_header, typ, tostring(err or status))
  end)
end
