local log   = require "spylog.log"
local Args  = require "spylog.args"
local uv    = require "lluv"
local ut    = require "lluv.utils"
local GNTP  = require "gntp"

local app = GNTP.Application.new{'SpyLog',
  notifications = {
    { 'BAN',
      -- title   = 'Ban',
      -- display = 'Ban',
      enabled = true,
    };
    { 'UNBAN',
      -- title   = 'Unban',
      -- display = 'Unban',
      enabled = true,
    };
  }
}

local reged = false

return function(action, cb)
  local options    = action.options
  local parameters = action.action.parameters

  local args, tail = Args.split(action.args)

  if not args then
    log.error("[%s] Can not parse argument string: %q", action.jail, action.args)
    return uv.defer(cb, info, nil)
  end

  if tail then
    log.warning("[%s] Unused command arguments: %q", action.jail, tail)
  end

  local subject  = parameters and parameters.fullsubj or args[1]
  local message  = parameters and parameters.fullmsg  or args[2]
  local priority = parameters and parameters.priority
  local action_type = string.upper(action.type)

  local address, port
  if options  then
    address = options.address
    port    = options.port
  end
  address = address and '127.0.0.1'
  port    = port or '23053'

  local growl = GNTP.Connector.lluv(app, {
    host    = address;
    port    = port;
    pass    = options.password;
    encrypt = options.encrypt;
    hash    = options.hash;
  })

  local function notify()
    growl:notify(action_type, {title = subject, text = message}, function(self, err, msg)
      if err then return uv.defer(cb, action, false, err) end
      return uv.defer(cb, action, true)
    end)
  end

  if not reged then
    growl:register(function(self, err, msg)
      if err then return uv.defer(cb, action, false, err) end
      reged = true
      notify()
    end)
  else notify() end
end

