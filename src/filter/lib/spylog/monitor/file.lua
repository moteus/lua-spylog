local uv        = require "lluv"
local ut        = require "lluv.utils"
local date      = require "date"
local log       = require "spylog.log"
local filemon   = require "spylog.filemon"

local unpack = unpack or table.unpack

local function file_monitor(fname, opt, cb)
  local eol = (opt or {}).eol or {'\r*\n', true}
  if type(eol) == 'string' then eol = {eol, false} end
  local buffer = ut.Buffer.new(unpack(eol, 1, 2))
  local monitor = filemon.new(opt)
  monitor:open(fname, function(self, err, data)
    if err then 
      return log.error("READ FILE: %s", tostring(err))
    end

    buffer:append(data)
    while true do
      local line = buffer:read_line()
      if not line then break end
      cb(line)
    end
  end)
end

local function file_filter(filter, t)
  return filter.match(t)
end

return {
  monitor = file_monitor;
  filter = file_filter;
}
