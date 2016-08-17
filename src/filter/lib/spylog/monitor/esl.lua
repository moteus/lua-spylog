local uv     = require "lluv"
local ut     = require "lluv.utils"
local esl    = require "lluv.esl"
local log    = require "spylog.log"

local FS_LOG_LEVELS_NAMES = {
  ['0'] = "CONSOLE";
  ['1'] = "ALERT";
  ['2'] = "CRIT";
  ['3'] = "ERR";
  ['4'] = "WARNING";
  ['5'] = "NOTICE";
  ['6'] = "INFO";
  ['7'] = "DEBUG";
}

local FS_LOG_LEVELS = {
  CONSOLE = '0';
  ALERT   = '1';
  CRIT    = '2';
  ERR     = '3';
  WARNING = '4';
  NOTICE  = '5';
  INFO    = '6';
  DEBUG   = '7';
}

local function esl_monitor(endpoint, opt, cb)
  local auth, address, port = ut.split_first(endpoint, "@", true)
  if not address then
    auth, address = 'ClueCon', auth
  end

  address, port = ut.split_first(address, ":", true)
  port = tonumber(port) or 8021

  local log_header = string.format('[esl] [%s:%d]', address, port)

  local reconnect_timeout = (opt and opt.reconnect or 30) * 1000
  local level, level_name = string.upper(tostring(opt and opt.level or 'WARNING'))
  level = FS_LOG_LEVELS[level] or level
  level_name = assert(FS_LOG_LEVELS_NAMES[level], 'Unknon log level: ' .. level)

  local reconnect_timer = uv.timer(0)

  local function connect()
    log.info("%s connecting ...", log_header)

    esl.Connection(address, port, auth)

    :open(function(self, err)
      if err then
        log.info("%s connected fail", log_header)
        return
      end

      log.info("%s connected", log_header)

      self:log(level_name, function(self, err, event)
        if err then return end
        local ok, status, msg = event:getReply()
        log.info('%s log command: %s %s', log_header, tostring(status), tostring(msg))
      end)

    end)

    :on('esl::event::LOG', function(self, eventName, event)
      cb(event)
    end)

    :on('esl::error::**', function(self, eventName, err)
      log.error('%s %s: %s', log_header, eventName, tostring(err))
      self:close()
      reconnect_timer:again(reconnect_timeout)
    end)
  end

  reconnect_timer:start(function(self)
    self:stop()
    connect()
  end)

end

local function esl_filter(filter, event)
  -- local file    = event:getHeader('Log-File')
  -- local line    = event:getHeader('Log-Line')
  -- local func    = event:getHeader('Log-Func')
  local level   = event:getHeader('Log-Level')
  -- local udata   = event:getHeader('User-Data')
  -- local chann   = event:getHeader('Text-Channel')

  -- this is console
  if level == '0' then return end

  local msg = event:getBody()

  return filter.match(msg)
end

return {
  monitor = esl_monitor;
  filter = esl_filter;
}
