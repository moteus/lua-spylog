local uv     = require "lluv"
local ut     = require "lluv.utils"
local log    = require "spylog.log"
local syslog = require "spylog.syslog"

local MAX_LINE_LENGTH = 4096

local function tcp_cli_monitor(proto, address, opt, cb)
  local address, port = ut.split_first(address,":", true)
  port = assert(tonumber(port), 'port is required')

  local log_header = string.format('[net/%s] [%s:%d]', proto, address, port)

  local eol = opt and opt.eol or '\r\n'
  local reconnect_timeout = (opt and opt.reconnect or 30) * 1000

  local reconnect_timer = uv.timer(0)

  local function connect()
    log.info("%s connecting ...", log_header)
    uv.tcp():connect(address, port, function(self, err)
      if err then
        self:close()
        log.error("%s can not connect: %s", log_header, tostring(err))
        return reconnect_timer:again(reconnect_timeout)
      end

      local buffer = ut.Buffer.new(eol)

      self:start_read(function(self, err, data)
        if err then
          self:close()
          log.error("%s recv error: %s", log_header, tostring(err))
          return reconnect_timer:again(reconnect_timeout)
        end

        buffer:append(data)
        while true do
          local line = buffer:read_line()
          if not line then
            if buffer.size and (buffer:size() > MAX_LINE_LENGTH) then
              log.alert('%s get too long line: %d `%s...`', log_header, buffer:size(), buffer:read_n(256))
              buffer:reset()
            end
            break
          end
          cb(line)
        end
      end)

      log.info("%s connected", log_header)
    end)
  end

  reconnect_timer:start(function(self)
    self:stop()
    connect()
  end)
end

local function net_monitor(endpoint, opt, cb)
  local proto, address = ut.split_first(endpoint,"://", true)

  if proto == 'tcp' then
    return tcp_cli_monitor(proto, address, opt, cb)
  end

  log.fatal('[net] unknown protocol: %', proto)

  assert(false)
end

local function net_filter(filter, msg)
  return filter.match(msg)
end

return {
  monitor = net_monitor;
  filter = net_filter;
}
