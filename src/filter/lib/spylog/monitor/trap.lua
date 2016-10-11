local ut   = require "lluv.utils"
local log  = require "spylog.log"
local trap = require "spylog.trap"
local net  = require "spylog.monitor.net"

local function trap_monitor(endpoint, opt, cb)
  local proto, address, port = ut.split_first(endpoint,"://", true)
  assert(proto == 'udp')

  address, port = ut.split_first(address,":", true)
  port = tonumber(port) or 162

  local log_header = string.format('[trap/%s] [%s:%d]', proto, address, port)

  return net.monitor(string.format('%s://%s:%d', proto, address, port), opt,
    function(data)
      local t = trap.decode(data)
      if not t then
        return log.warning("%s recv non trap: %q", log_header, trap.bin2hex(data))
      end

      cb(t)
    end, log_header
  )
end

local function trap_filter(filter, t)
  if not (filter.trap[t.specific] or filter.trap[t.enterprise]) then return  end

  for i = 1, #t.data do
    local msg = t.data[i][2]
    if type(msg) == 'string' then
      local capture = filter.match(msg)
      if capture then return capture end
    end
  end
end

return {
  monitor = trap_monitor;
  filter = trap_filter;
}