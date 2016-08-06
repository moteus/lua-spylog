local uv     = require "lluv"
local ut     = require "lluv.utils"
local log    = require "spylog.log"
local syslog = require "spylog.syslog"

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

  address, port = ut.split_first(address,":", true)
  port = tonumber(port or 514)

  uv.udp():bind(address, port, function(self, err)
    if err then
      self:close()
      return log.fatal("Can not start syslog monitor: %s", tostring(err))
    end

    self:start_recv(function(self, err, data, host, port)
      if err then
        return log.error("Recv syslog: %s", tostring(err))
      end

      local pri, msg = decode(syslog.unpack(data))
      if not pri then
        return log.warning("Recv non syslog: %q", data)
      end

      log.trace("syslog: %d %q", pri, msg)

      cb(pri, msg)
    end)

    log.info("Syslog monitor started on %s://%s:%d", proto, address, port)
  end)
end

local function syslog_filter(filter, pri, msg)
  return filter.match(msg)
end

return {
  monitor = syslog_monitor;
  filter = syslog_filter;
}

