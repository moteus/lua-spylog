local uv        = require "lluv"
local ut        = require "lluv.utils"
local socket    = require "lluv.ssl.luasocket"
local ssl       = require "lluv.ssl"
local sendmail_ = require "sendmail"
local Args      = require "spylog.args"
local log       = require "spylog.log"
local var       = require "spylog.var"

local SSL_CONTEXT = {}

local function CTX(opt)
  if not opt then return end

  local ctx = SSL_CONTEXT[opt]
  if not ctx then
    ctx = ssl.context(opt)
    SSL_CONTEXT[opt] = ctx
  end

  return ctx
end

return function(task, cb)
  local action, options = task.action, task.options
  local context, command = action, action.cmd
  local parameters = action.parameters or command.parameters

  if action.parameters then context = var.combine{action, action.parameters, command.parameters}
  elseif command.parameters then context = var.combine{action, command.parameters} end

  local log_header = string.format("[%s][%s][%s]", action.jail, action.action, task.type)

  local command_args = Args.apply_tags(command[2], context)
  local args, tail = Args.split(command_args)

  if not args then
    log.error("%s Can not parse argument string: %q", log_header, action.jail, command_args)
    return uv.defer(cb, task, nil, tail)
  end

  if tail then
    log.warning("%s unused command arguments: %q", log_header, tail)
  end

  local subject = parameters and parameters.fullsubj or args[1]
  local message = parameters and parameters.fullmsg  or args[2]
  local charset = parameters and parameters.charset  or options.charset

  ut.corun(function()
    local ok, err = sendmail_{
      server = {
        address  = options.server.address;
        user     = options.server.user;
        password = options.server.password;
        ssl      = CTX(options.server.ssl);
        create   = options.server.ssl and socket.ssl;
      },

      from = {
        title   = parameters and parameters.sendername or options.from.title;
        address = parameters and parameters.sender     or options.from.address;
      },

      to = {
        title   =  parameters and parameters.destname or options.to.title;
        address =  parameters and parameters.dest     or options.to.address;
      },

      message = {
        subject = {subject, charset = charset},
        text    = {message, charset = charset},
      }
    }

    uv.defer(cb, task, ok, err)
  end)
end
