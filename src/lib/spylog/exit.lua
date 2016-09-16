local SERVICE = require "LuaService"
local uv      = require "lluv"
uv.poll_zmq   = require "lluv.poll_zmq"
local log     = require "spylog.log"

local function stop_service()
  log.info("Stopping service...")
  uv.stop()
end

local function register_stop_monitor(...)
  local pipe = ...
  if not pipe or not pipe.recvx then pipe = nil end

  if pipe then
    log.info("Run as child thread")

    uv.poll_zmq(pipe):start(function(handle, err, pipe)
      if err then
        if err:name() ~= 'ETERM' then
          log.fatal("pipe poll: ", err)
        end
        return stop_service()
      end

      local msg, err = pipe:recvx()
      if not msg then
        if err:name() == 'ETERM' then
          return stop_service()
        end
        if err:name() ~= 'EAGAIN' then
          log.fatal("recv msg: %s", tostring(err))
        end
        return
      end

      if msg == 'CLOSE' then
        return stop_service()
      end
    end)

  elseif SERVICE.RUN_AS_SERVICE then
    log.info("Run as service")

    uv.timer():start(1000, 1000, function()
      if SERVICE.check_stop(0) then
        stop_service()
      end
    end)
  else
    log.info("Run as console")

    uv.signal():start(uv.SIGINT,   stop_service)

    uv.signal():start(uv.SIGBREAK, stop_service)
  end
end

return {
  start_monitor = register_stop_monitor;
  stop_service  = stop_service;
}
