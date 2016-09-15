local uv = require "lluv"
local ut = require "lluv.utils"

local SIGNALS ={
  SIGINT   = uv.SIGINT,
  SIGBREAK = uv.SIGBREAK,
  SIGHUP   = uv.SIGHUP,
  SIGWINCH = uv.SIGWINCH,
  SIGPIPE  = uv.SIGPIPE,
  SIGQUIT  = uv.SIGQUIT,
  SIGILL   = uv.SIGILL,
  SIGABRT  = uv.SIGABRT,
  SIGTRAP  = uv.SIGTRAP,
  SIGIOT   = uv.SIGIOT,
  SIGEMT   = uv.SIGEMT,
  SIGFPE   = uv.SIGFPE,
  SIGKILL  = uv.SIGKILL,
  SIGBUS   = uv.SIGBUS,
  SIGSEGV  = uv.SIGSEGV,
  SIGSYS   = uv.SIGSYS,
  SIGALRM  = uv.SIGALRM,
  SIGUSR1  = uv.SIGUSR1,
  SIGUSR2  = uv.SIGUSR2,
  SIGCHLD  = uv.SIGCHLD,
  SIGCLD   = uv.SIGCLD,
  SIGPWR   = uv.SIGPWR,
  SIGXCPU  = uv.SIGXCPU,
  SIGTERM  = uv.SIGTERM,
}

local SIGNALS_INVERT = {}
for name, value in pairs(SIGNALS) do
  SIGNALS_INVERT[value] = name
end

local function signal_name(s)
  return SIGNALS_INVERT[s] or string.format('%d', s)
end

local StatusError = ut.class() do

function StatusError:__init(status, signal, stderr)
  self._staus   = assert(status)
  self._signal  = assert(signal or SIGNALS.SIGTERM)
  self._stderr  = stderr

  return self
end

function StatusError:cat()    return 'SPAWN'        end

function StatusError:name()   return 'ESTATUS'      end

function StatusError:no()     return -1             end

function StatusError:status() return self._staus    end

function StatusError:signal() return self._signal   end

function StatusError:signal_name() return signal_name(self._signal) end

function StatusError:msg() 
  return string.format("Status: %d Signal: %s", self:status(), self:signal_name())
end

function StatusError:ext()    return end

function StatusError:__tostring()
  local err = string.format("[%s][%s] %s",
    self:cat(), self:name(), self:msg()
  )
  return err
end

function StatusError:__eq(rhs)
  return self:cat() == rhs:cat()
    and self:name() == rhs:name()
    and self:status() == rhs:status()
end

end

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
      process:kill()
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

    local command_id, active_command = i, command
    local process = uv.spawn(opt, function(handle, err, status, signal)
      processes[handle] = nil
      if timer and not next(processes) then
        timer:close()
        timer = nil
      end

      if not err then
        if not (active_command.ignore_status or status == 0) then
          err = StatusError.new(status, signal)
        end
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

local function chain_(i, commands, timeout, cb)
  local command = commands[i]
  if not command then return uv.defer(cb, 0, 'done') end

  spawn(command[1], command[2], timeout, function(typ, err, status, signal)
    if typ == 'exit' then

      if not err then
        if not (command.ignore_status or status == 0) then
          err = StatusError.new(status, signal)
        end
      end

      uv.defer(cb, i, 'exit', err, status, signal)

      if not err then
        if command.ignore_status or status == 0 then
          return uv.defer(chain_, i + 1, commands, timeout, cb)
        end
      end

      return uv.defer(cb, 0, 'done')
    end

    cb(i, typ, err, status, signal)
  end)
end

local function chain(commands, timeout, cb)
  return chain_(1, commands, timeout, cb)
end

return setmetatable({
  estatus = StatusError.new;
  pipe  = pipe;
  chain = chain;
},{__call = function(_, ...) return spawn(...) end})
