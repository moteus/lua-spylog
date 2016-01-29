local uv   = require "lluv"
local ut   = require "lluv.utils"
local path = require "path"

local EOF = uv.error("LIBUV", uv.EOF);

local AppendFileMonitor = ut.class() do

function AppendFileMonitor:__init(opt)
  opt = opt or {}
  self._fname    = nil
  self._file     = nil
  self._event    = nil
  self._buffer   = uv.buffer(1024)
  self._offset   = nil
  self._reading  = nil
  if opt.skeep == true or opt.skeep == nil then
    self._skeep = nil
  else
    self._skeep = true -- true mean do not skeep
  end

  if opt.poll then
    assert(type(opt.poll) == 'number', 'poll should be number but got: ' .. type(opt.poll))
    assert(opt.poll >= 1, 'poll should be at least one second')
    self._poll_interval = opt.poll * 1000
  end

  self._on_read_proxy   = function(...) return self:_on_read(...) end

  return self
end

function AppendFileMonitor:_do_read()
  if (not self._reading) and (self._file) then
    self._reading = true
    self._file:read(self._buffer, self._offset, self._on_read_proxy)
  end
end

function AppendFileMonitor:_do_open(cb)
  if self._skeep then
    self._skeep = path.size(self._fname) or 0
  end
  uv.fs_open(self._fname, "r", function(file, err, path)
    self:_on_open(err, file)
  end)
end

function AppendFileMonitor:_on_read(file, err, buf, size)
  self._reading = false

  if err and err:name() ~= 'EOF' then self:_cb(err) end

  if err or size == 0 then return end

  self._offset = self._offset + size
  local data = buf:to_s(size)

  self:_do_read()

  self._cb(self, nil, data, self._offset)
end

function AppendFileMonitor:_on_open(err, file)
  self._offset = self._skeep or 0
  self._skeep  = false -- only once

  if err then return self:_on_error(self, err) end

  self._file = file

  self:_do_read()
end

function AppendFileMonitor:_on_rename()
  if self._file then 
    self._file:close()
    self._file = nil
  end
end

function AppendFileMonitor:_on_change()
  self:_do_read()
end

function AppendFileMonitor:_on_error(err)
  self:_cb(err)
end

function AppendFileMonitor:open(fname, cb)
  self._fname = fname
  self._cb    = cb

  if (not self._file) and path.exists(fname) then
    -- We skip existed content of first file.
    -- e.g. log already has data for a week and we just start filter service.
    if self._skeep == nil then
      self._skeep = true
    end
    self:_do_open()
  end

  self._event = uv.fs_event():start(fname, function(_, err, _, ev)
    if ev == uv.RENAME then
      return self:_on_rename()
    end

    if (not self._file) and path.exists(fname) then
      return self:_do_open()
    end

    if self._file and (ev == uv.CHANGE) then
      return self:_on_change()
    end
  end)

  if self._poll_interval then
    self._poll_event = uv.fs_poll():start(fname, self._poll_interval, function()end)
  end

end

function AppendFileMonitor:close(cb)
  self:stop(function()
    self._file:close()
    if self._poll_event then
      self._poll_event:close()
    end
    self._event:close(function()
      cb(self)
    end)
  end)
end

end

return AppendFileMonitor
