local SERVICE      = require "LuaService"
local config       = require "spylog.config"
config.LOG.prefix  = "[spylog] "
config.main_thread = true
config.LOG.multithread = true
---------------------------------------------------

local version   = require "spylog.version"
local zthreads  = require "lzmq.threads"
local ztimer    = require "lzmq.timer"
local uv        = require "lluv"
local stp       = require "StackTracePlus"
local loglib    = require "log"
local log       = require "spylog.log"
local exit      = require "spylog.exit"

log.info('Starting %s version %s. %s', version._NAME, version._VERSION, version._COPYRIGHT)

local init_thread = function(...)
  require "LuaService"
  local config  = require "spylog.config"
  config.LOG.multithread = true
  return ...
end

local THREADS = {
  {'filter', '@../filter/main.lua'};
  {'jail',   '@../jail/main.lua'  };
  {'action', '@../action/main.lua'};
}

local threads = {}
local function start_threads()
  for _, t in ipairs(THREADS) do
    threads[t[1]] = zthreads.xactor{t[2], prelude=init_thread}:start()
    ztimer.sleep(1000)
  end
end

local ok, err = pcall(start_threads)
if not ok then
  log.alert("Can not start work thread: %s", tostring(err))
  ztimer.sleep(500)
  return SERVICE.exit()
end

exit.start_monitor()

uv.timer():start(1000, 10000, function()
  for name, thread in pairs(threads) do
    if not thread:alive() then
      log.alert("%s thread dead!", name)
      return exit.stop_service()
    end
  end
end)

local ok, err = pcall(uv.run, stp.stacktrace)

if not ok then
  log.alert(err)
end

for _, thread in pairs(threads) do
  if thread:alive() then
    thread:send("CLOSE")
  end
end

log.info("Service stopped")

-- allow proceed all log messages
ztimer.sleep(1000)

-- terminate workers and close files
loglib.close()

SERVICE.exit()
