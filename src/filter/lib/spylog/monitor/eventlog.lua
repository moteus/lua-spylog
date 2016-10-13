local ut       = require "lluv.utils"
local log      = require "spylog.log"
local EventLog = require "spylog.eventlog"
local trap     = require "spylog.monitor.trap"

local function trap_monitor(endpoint, opt, cb, log_header)
  local proto, address, port = ut.split_first(endpoint, "://", true)
  assert(proto == 'udp')

  address, port = ut.split_first(address,":", true)
  port = tonumber(port) or 162

  endpoint = string.format('%s://%s:%d', proto, address, port)

  local log_header = log_header or string.format('[eventlog/%s] [%s:%d]', proto, address, port)

  return trap.monitor(endpoint, opt, cb, log_header)
end

local function trap_filter(filter, t)
  local msg = filter.events(t) and EventLog.trap2text(t)
  if type(msg) == 'string' then
    return filter.match(msg)
  end
end

return {
  monitor = trap_monitor;
  filter = trap_filter;
}