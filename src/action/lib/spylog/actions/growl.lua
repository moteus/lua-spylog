local log   = require "spylog.log"
local Args  = require "spylog.args"
local uv    = require "lluv"
local ut    = require "lluv.utils"
local GNTP  = require "gntp"

local app = GNTP.Application.new{'SpyLog',
  notifications = {
    { 'BAN',
      -- title   = 'Ban',
      -- display = 'Ban',
      enabled = true,
    };
    { 'UNBAN',
      -- title   = 'Unban',
      -- display = 'Unban',
      enabled = true,
    };
  }
}

local reged = {}

local function decode_growl_address(url)
  local auth, address = ut.split_first(url, '@', true)
  if not address then address, auth = auth end
  local port
  address, port = ut.split_first(address, ':', true)
  if not port then port = '23053' end
  local pass, hash, enc
  if auth then pass, hash, enc = ut.usplit(auth, ':', true) end
  return address, port, pass, hash, enc
end

return function(action, cb)
  local options    = action.options
  local parameters = action.action.parameters
  local log_header = '[growl][' .. action.uuid .. ']'

  log.debug('%s execute start', log_header)

  local args, tail = Args.split(action.args)

  if not args then
    log.error("%s [%s] Can not parse argument string: %q", log_header, action.jail, action.args)
    return uv.defer(cb, info, nil)
  end

  if tail then
    log.warning("%s [%s] Unused command arguments: %q", log_header, action.jail, tail)
  end

  local subject     = parameters and parameters.fullsubj or args[1]
  local message     = parameters and parameters.fullmsg  or args[2]
  local priority    = parameters and parameters.priority
  local icon        = parameters and parameters.icon
  local sticky      = parameters and parameters.sticky
  local notify_type = string.upper(action.type)

  local count, address, port, password, encrypt, hash
  local growl, growl_err

  local function send_notify()
    growl:notify(notify_type, {
      title    = subject,
      text     = message,
      priority = priority,
      sticky   = sticky,
      icon     = icon,
    }, function(self, err, msg)
      count = count - 1
      growl_err = growl_err or err
      if count > 0 then return end
      if growl_err then
        uv.defer(cb, action, false, growl_err)
      else
        uv.defer(cb, action, true)
      end
      log.debug('%s execute done', log_header)
    end)
  end

  local function send_register()
    growl:register(function(self, err, msg)
      if err then
        count = count - 1
        if count <= 0 then
          growl_err = err
        else
          uv.defer(cb, action, false, err)
          log.debug('%s execute done', log_header)
        end
        return
      end

      reged[address] = true

      send_notify()
    end)
  end

  local function notify()
    growl = GNTP.Connector.lluv(app, {
      host    = address or '127.0.0.1';
      port    = port or '23053';
      pass    = password;
      encrypt = encrypt;
      hash    = hash;
    })

    log.debug('%s notify %s: [%s] %s', log_header, address, notify_type, subject)

    if not reged[address] then return send_register() end
    return send_notify()
  end

  local dest = parameters and parameters.dest

  if dest and string.find(dest, '[;,]') then
    dest = ut.split(dest, '[;,]')
    count = #dest
    for i = 1, #dest do
      address, port, password, hash, encrypt = decode_growl_address(dest[i])
      if address then
        notify()
      else
        log.error('%s Invalid growl destination: %s', log_header, dest[i])
        count = count - 1
      end
      if count == 0 then
        uv.defer(cb, action, false, 'Invalid destinations')
      end
    end
    return
  end

  count = 1

  if type(dest) == 'string' then
    address, port, password, hash, encrypt = decode_growl_address(dest)
    if not address then
      log.error('%s Invalid growl destination: %s', log_header, dest)
      return uv.defer(cb, action, false, 'Invalid destinations')
    end
  elseif options then
    address  = options.address
    port     = options.port
    password = options.password;
    hash     = options.hash;
    encrypt  = options.encrypt;
  end

  notify()
end
