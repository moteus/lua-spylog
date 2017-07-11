local uv      = require "lluv"
local ut      = require "lluv.utils"
local spawn   = require "spylog.spawn".spawn_ex
local log     = require "spylog.log"
local Args    = require "spylog.args"
local path    = require "path"
local environ = require "environ.process"

local MAX_LINE_LENGTH = 4096

local function build_cb(buffer, cb)
  return function(data)
    buffer:append(data)
    while true do
      local str = buffer:read("*l")
      if not str then break end
      cb(str)
    end
  end
end

local function process_monitor(cmd, opt, cb)
  local opt = opt or {}

  local proto = 'process'

  local args, tail = opt.args
  if args then
    if type(args) == 'string' then
      args, tail = Args.split(args)

      if not args then
        log.error("[process][%s] Can not parse argument string: %s", cmd, opt.args)
        return false
      end
    end
  else
    local tmp_cmd = cmd
    cmd, args, tail = Args.split_command(cmd)
    if not cmd then
      log.error("[process] Can not parse command string: %s", cmd)
    end
  end

  cmd = path.normalize(cmd)

  local source_name = opt.__name or (cmd and path.basename(cmd)) or 'unknown'
  local log_header = '[' .. proto .. ']' ..'[' .. source_name .. ']'

  if tail and #tail > 0 then
    log.warning("%s Unused command arguments: %q", log_header, tail)
  end

  local env
  if opt.env then
    env = {}
    for k, v in pairs(opt.env) do
      if type(k) == 'number' then
        env[#env + 1] = v .. '=' .. environ.getenv(v)
      else
        env[#env + 1] = k .. '=' .. environ.expand(v)
      end
    end
  end

  local eol
  if type(opt.eol) == 'table' then
    eol = opt.eol
  else
    eol = {opt.eol}
  end

  local restart = opt.restart or 10
  if not tonumber(restart) then
    log.warning("%s restart timeout have to be a number but got: %q", log_header, tostring(restart))
    restart = 10
  end

  restart = tonumber(restart)

  if restart < 1 then
    log.warning("%s restart timout have to be greater than 1 but got: %d", log_header, restart)
  end

  restart = restart * 1000

  local max_line = opt and opt.max_line or MAX_LINE_LENGTH
  if not tonumber(max_line) then
    log.warning("%s max_line option have to be a number but got: %q", log_header, tostring(restart))
    max_line = MAX_LINE_LENGTH
  end

  max_line = tonumber(max_line)

  if max_line < MAX_LINE_LENGTH then
    log.warning("%s too short `max_line` option: %d, use default one: %d", log_header, max_line, MAX_LINE_LENGTH)
  end

  local monitor = {}
  if type(opt.monitor) == 'string' then
    monitor[opt.monitor] = 'true'
  elseif type(opt.monitor) == 'table' then
    for i = 1, #opt.monitor do
      monitor[ opt.monitor[i] ] = true
    end
  end
  if not (monitor.sdtout or monitor.sdterr) then
    monitor.stdout = true
  end

  local stdout_buffer, on_stdout, stderr_buffer, on_stderr
  if monitor.stdout then
    stdout_buffer = ut.Buffer.new(eol[1], eol[2])
    on_stdout = build_cb(stdout_buffer, cb)
  end

  if monitor.stderr then
    stderr_buffer = ut.Buffer.new(eol[1], eol[2])
    on_stderr = build_cb(stderr_buffer, cb)
  end

  local restart_timer = uv.timer()

  local function start()
    log.info('%s creating process: %s %s', log_header, cmd, (args and table.concat(args, ' ') or ''))

    if stdout_buffer then stdout_buffer:reset() end
    if stderr_buffer then stderr_buffer:reset() end

    local pid
    local process, err = spawn(cmd, args, env, nil,
      function(typ, err, status, signal)
        if typ == 'exit' then
          restart_timer:again(restart)
          log.warning('%s process with pid %s exit %s; status: %s; signal: %s', log_header, tostring(pid), tostring(err), tostring(status), tostring(signal))
        end
      end,
      on_stdout, on_stderr
    )

    if not process then
      log.error('%s can not spawn process: %s', log_header, tostring(err))
      restart_timer:again(restart)
    end

    pid = err
    log.info('%s created process with pid %s', log_header, tostring(pid))
  end

  restart_timer:start(function(self)
    self:stop()
    start()
  end)
end

local function process_filter(filter, t)
  return filter.match(t)
end

return {
  monitor = process_monitor;
  filter = process_filter;
}
