local ut     = require "lluv.utils"
local log    = require "spylog.log"
local syslog = require "spylog.syslog"
local net    = require "spylog.monitor.net"

local function decode(fmt, ...)
  local pri, ver, ts, host, app, procid, msgid, sdata, msg
  if fmt == 'rfc3164' then
    local mon, day, time
    pri, mon, day, time, host, msg = ...
  elseif fmt == 'rfc5424' then
    pri, ver, ts, host, app, procid, msgid, sdata, msg = ...
  end
  return pri, msg
end

local function syslog_monitor(endpoint, opt, cb)
  local proto, address, port = ut.split_first(endpoint,"://", true)
  assert(proto == 'udp')

  address, port = ut.split_first(address, ":", true)
  port = tonumber(port) or 514

  local log_header = string.format('[syslog/%s] [%s:%d]', proto, address, port)

  return net.monitor(string.format('%s://%s:%d', proto, address, port), opt,
    function(data)
      local pri, msg = decode(syslog.unpack(data))
      if not pri then
        return log.warning("%s recv non syslog: %q", log_header, data)
      end

      cb(pri, msg)
    end, log_header
  )
end

local function syslog_filter(filter, pri, msg)
  return filter.match(msg)
end

return {
  monitor = syslog_monitor;
  filter = syslog_filter;
}

