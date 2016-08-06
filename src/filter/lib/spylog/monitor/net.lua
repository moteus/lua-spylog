local uv     = require "lluv"
local ut     = require "lluv.utils"
local log    = require "spylog.log"
local syslog = require "spylog.syslog"

local function tcp_cli_monitor(proto, address, opt, cb)
  local address, port = ut.split_first(address,":", true)
  port = assert(tonumber(port), 'port is required')

  local eol = opt and opt.eol or '\r\n'
  local reconnect_timeout = opt and opt.reconnect or 30000

  local connect, reconnect

  function connect()
    uv.tcp():connect(address, port, function(self, err)
      if err then
        self:close()
        log.error("[net/%s] can not connect to %s:%d monitor: %s", proto, address, port, tostring(err))
        return reconnect()
      end

      local buffer = ut.Buffer.new(eol)

      self:start_read(function(self, err, data)
        if err then
          self:close()
          log.error("[net/%s] recv error: %s", proto, tostring(err))
          return reconnect()
        end

        buffer:append(data)
        while true do
          local line = buffer:read_line()
          if not line then break end

          log.trace("[net/%s] recv: %q", proto, line)

          cb(line)
        end
      end)

      log.error("[net/%s] connected to %s:%d", proto, address, port)
    end)
  end

  function reconnect()
    uv.timer(reconnect_timeout, function(self)
      self:close()
      connect()
    end)
  end

  connect()
end

local function net_monitor(endpoint, opt, cb)
  local proto, address = ut.split_first(endpoint,"://", true)

  if proto == 'tcp' then
    return tcp_cli_monitor(proto, address, opt, cb)
  end

  log.fatal('unknown protocol: %', proto)

  assert(false)
end

local function net_filter(filter, msg)
  return filter.match(msg)
end

return {
  monitor = net_monitor;
  filter = net_filter;
}

