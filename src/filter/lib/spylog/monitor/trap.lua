local uv   = require "lluv"
local ut   = require "lluv.utils"
local log  = require "spylog.log"
local trap = require "spylog.trap"

local function trap_monitor(endpoint, opt, cb)
  local proto, address, port = ut.split_first(endpoint,"://", true)
  assert(proto == 'udp')

  address, port = ut.split_first(address,":", true)
  port = tonumber(port or 162)

  uv.udp():bind(address, port, function(self, err)
    if err then
      self:close()
      return log.fatal("Can not start trap monitor: %s", tostring(err))
    end

    self:start_recv(function(self, err, data, host, port)
      if err then
        return log.error("Recv trap: %s", tostring(err))
      end

      local t = trap.decode(data)
      if not t then
        return log.warning("Recv non trap: %s", trap.bin2hex(data))
      end

      log.trace("trap: %s", trap.bin2hex(data))

      cb(t)
    end)

    log.info("Trap monitor started on %s://%s:%d", proto, address, port)
  end)
end

local function trap_filter(filter, t)
  if not (filter.trap[t.specific] or filter.trap[t.enterprise]) then return  end

  for i = 1, #t.data do
    local msg = t.data[i][2]
    if type(msg) == 'string' then
      local date, ip = filter.match(msg)
      if ip then return date, ip end
    end
  end
end

return {
  monitor = trap_monitor;
  filter = trap_filter;
}