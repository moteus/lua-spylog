local uv = require "lluv"

local function P(pipe, read)
  return {
    stream = pipe,
    flags = uv.CREATE_PIPE + 
            (read and uv.READABLE_PIPE or uv.WRITABLE_PIPE) +
            uv.PROCESS_DETACHED
  }
end

local function spawn(file, args, timeout, cb)
  local stdout = uv.pipe()
  local stderr = uv.pipe()

  if type(args) == 'string' then
    args = {args}
  end

  local opt = {
    file = file,
    args = args or {},
    stdio = {{}, P(stdout, false), P(stderr, false)},
  }

  local exit_code, run_error, timer

  local proc, pid = uv.spawn(opt, function(handle, err, status, signal)
    handle:close()
    if timer then
      timer:close()
      timer = nil
    end

    cb('exit', err, status, signal)
  end)

  if proc and timeout then
    timer = uv.timer():start(timeout, function()
      timer:close()
      timer = nil
      proc:kill()
    end)
  end

  local function on_data(self, err, data)
    local typ = (self == stdout) and 'stdout' or 'stderr'
    if err and err:name() == 'EOF' then
      return
    end
    cb(typ, err, data)
  end

  stdout:start_read(on_data)
  stderr:start_read(on_data)
end

return spawn
