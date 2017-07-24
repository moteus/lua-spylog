local uv     = require "lluv"
local ut     = require "lluv.utils"
local Esl    = require "lluv.esl"
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

  local reconnect_timeout = (opt and opt.reconnect or 30)
  local level, level_name = string.upper(tostring(opt and opt.level or 'WARNING'))
  level = FS_LOG_LEVELS[level] or level
  level_name = assert(FS_LOG_LEVELS_NAMES[level], 'Unknon log level: ' .. level)

  local esl = Esl.Connection{address, port, auth,
    reconnect = reconnect_timeout; no_execute_result = true; no_bgapi = true;
  }

  esl:on('esl::reconnect', function(self, eventName)
    log.info("%s connected", log_header)

    self:log(level_name, function(self, err, event)
      if err then
        log.error('%s log command: %s', log_header, tostring(err))
        return
      end

      local ok, status, msg = event:getReply()
      log.info('%s log command: %s %s', log_header, tostring(status), tostring(msg))
    end)
  end)

  esl:on('esl::disconnect', function(self, eventName, err)
    log.info("%s disconnected: %s", log_header, tostring(err))
  end)

  esl:on('esl::event::LOG', function(self, eventName, event)
    cb(event)
  end)

  esl:on('esl::error::**', function(self, eventName, err)
    log.error('%s %s: %s', log_header, eventName, tostring(err))
  end)

  esl:on('esl::close', function(self, eventName, err)
    log.debug('%s %s: %s', log_header, eventName, tostring(err))
  end)

  esl:open()
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
