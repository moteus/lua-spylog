local ut   = require "lluv.utils"
local log  = require "spylog.log"
local trap = require "spylog.trap"
local net  = require "spylog.monitor.net"

local LVL_TRACE = require "log".LVL.TRACE

local function append(t, v) t[#t+1] = v return t end

local active_monitors = {}

local function trap_monitor(endpoint, opt, cb, log_header)
  local proto, address, port = ut.split_first(endpoint, "://", true)
  assert(proto == 'udp')

  address, port = ut.split_first(address,":", true)
  port = tonumber(port) or 162

  endpoint = string.format('%s://%s:%d', proto, address, port)

  local log_header = log_header or string.format('[trap/%s] [%s:%d]', proto, address, port)

  local active_monitor = active_monitors[endpoint]

  if not active_monitor then
    active_monitor = {}
    active_monitors[endpoint] = active_monitor

    net.monitor(endpoint, opt,
      function(data)
        local t = trap.decode(data)
        if not t then
          return log.warning("%s recv non trap: %q", log_header, trap.bin2hex(data))
        end

        if log.lvl() >= LVL_TRACE then
          log.trace('%s %s', log_header, trap.bin2hex(data))
        end

        for i = 1, #active_monitor do
          active_monitor[i](t)
        end
      end, log_header
    )
  end

  append(active_monitor, cb)
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