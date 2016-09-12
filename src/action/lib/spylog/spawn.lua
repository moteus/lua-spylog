local uv = require "lluv"

local function P(read, write, pipe)
  local ioflags = 0
  if read  then ioflags = ioflags + uv.READABLE_PIPE end
  if write then ioflags = ioflags + uv.WRITABLE_PIPE end
  if ioflags ~= 0 then
    if not pipe then
      pipe = uv.pipe()
      ioflags = ioflags + uv.CREATE_PIPE
    else
      ioflags = ioflags + uv.INHERIT_STREAM
    end
  end

  return {
    stream = pipe,
    flags  = ioflags + uv.PROCESS_DETACHED
  }
end

local function spawn(file, args, timeout, cb)
  local stdout = P(false, true)
  local stderr = P(false, true)

  if type(args) == 'string' then
    args = {args}
  end

  local opt = {
    file = file,
    args = args or {},
    stdio = {{}, stdout, stderr},
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

  stdout.stream:start_read(on_data)
  stderr.stream:start_read(on_data)
end

local function pipe(commands, timeout, cb)
  local processes, timer = {}

  local function interrupt()
    if timer then
      timer:close()
      timer = nil
    end

    for process in pairs(processes) do
      processes[process] = nil
      process:kill(function() end)
    end
  end

  local last_id, stdout, stderr
  for i, command in ipairs(commands) do
    local file, args = command[1], command[2]

    if type(args) == 'string' then args = {args} end

    local stdin = stdout and P(true, false, stdout.stream) or {}
    stdout = P(false, true)
    stderr = P(false, true)

    local opt = {
      file  = file,
      args  = args or {},
      stdio = {stdin or {}, stdout, stderr},
    }

    local command_id = i
    local process = uv.spawn(opt, function(handle, err, status, signal)
      processes[handle] = nil
      if timer and not next(processes) then
        timer:close()
        timer = nil
      end

      cb(command_id, 'exit', err, status, signal)

      if not next(processes) then
        cb(0, 'done')
      end
    end)

    processes[process] = true

    stderr.stream:start_read(function(self, err, data)
      if err and err:name() == 'EOF' then return end
      cb(command_id, 'stderr', err, data)
    end)
  end

  if stdout then
    local command_id = #commands
    stdout.stream:start_read(function(self, err, data)
      if err and err:name() == 'EOF' then return end
      cb(command_id, 'stdout', err, data)
    end)
  end

  if next(processes) and timeout then
    timer = uv.timer():start(timeout, function()
      interrupt(cb)
    end)
  end
end

return spawn
