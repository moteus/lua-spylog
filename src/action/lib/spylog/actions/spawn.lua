local uv      = require "lluv"
local spawn   = require "spylog.spawn"
local Args    = require "spylog.args"
local log     = require "spylog.log"

return function(action, cb)
  local cmd = action.cmd
  local args, tail = Args.split(action.args)

  if not args then
    log.error("[%s] Can not parse argument string: %q", action.jail, action.args)
    return uv.defer(cb, info, nil)
  end

  if tail then
    log.warning("[%s] Unused command arguments: %q", action.jail, tail)
  end

  spawn(cmd, args, action.options.timeout, function(typ, err, status, signal)
    if typ == 'exit' then
      if (not err) and (status ~= 0) then
        err = ("status: %q"):format(status)
      end
      return uv.defer(cb, action, status == 0, err)
    end
    return log.trace("[%s] COMMAND OUTPUT: [%s] %s", action.jail, typ, tostring(err or status))
  end)
end
