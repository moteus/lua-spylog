local uv        = require "lluv"
local ut        = require "lluv.utils"
local date      = require "date"
local log       = require "spylog.log"
local filemon   = require "spylog.filemon"

local MAX_LINE_LENGTH = 4096

local unpack = unpack or table.unpack

local function file_monitor(fname, opt, cb)
  local log_header = string.format('[file:%s]', fname)

  local eol = (opt or {}).eol or {'\r*\n', true}
  if type(eol) == 'string' then eol = {eol, false} end
  local buffer = ut.Buffer.new(unpack(eol, 1, 2))
  local monitor = filemon.new(opt)

  monitor:open(fname, function(self, err, data)
    if err then 
      return log.error("%s READ FILE: %s", log_header, tostring(err))
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
end

local function file_filter(filter, t)
  return filter.match(t)
end

return {
  monitor = file_monitor;
  filter = file_filter;
}
