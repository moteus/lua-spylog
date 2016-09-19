local Service = require "LuaService"

local CONFIG_DIR = string.match(Service.PATH, "^(.-)[\\/][^\\/]+$")

local WHITE_IP = {}

local SOURCES = {}

local FILTERS = {}

local JAILS = {}

local ACTIONS = {}

local CONNECTIONS = {}

local LOG = {}

local FILTER = {}

local JAIL = {}

local ACTION = {}

local function load_config(file, env)
  local fn
  if setfenv then
    fn = assert(loadfile(file))
    setfenv(fn, env)
  else
    fn = assert(loadfile(file, "bt", env))
  end
  return fn()
end

local function load_configs(base)
  local path = require "path"

  local function append(t, v)
    t[#t + 1] = v
  end

  local function appender(t)
    return function(v) return append(t, v) end
  end

  local main_config = path.join(base, "config", "spylog.lua")

  load_config(main_config, {
    LOG      = function(t) LOG      = t end;
    WHITE_IP = function(t) WHITE_IP = t end;
    FILTER   = function(t) FILTER   = t end;
    JAIL     = function(t) JAIL     = t end;
    ACTION   = function(t) ACTION   = t end;
    CONNECT    = function(t)
      for k, v in pairs(t) do CONNECTIONS[k] = v end
    end;
  })

  local env = {
    FILTER     = appender(FILTERS);
    JAIL       = appender(JAILS);
    ACTION     = function(t)
      local name = t[1]
      t[1], t[2] = t[2]
      ACTIONS[name] = t
    end;
    SOURCE     = function(t)
      local name = t[1]
      t[1], t[2] = t[2]
      SOURCES[name] = t
    end;
    WHITE_IP   = WHITE_IP;
  }

  for _,cfg in ipairs{'sources', 'filters', 'jails', 'actions'} do
    path.each(path.join(base, "config", cfg, "*.lua"), "f", function(fname)
      load_config(fname, env)
    end, {recurse=true})
  end

end

load_configs(CONFIG_DIR)

return {
  CONFIG_DIR  = CONFIG_DIR;
  FILTERS     = FILTERS;
  JAILS       = JAILS;
  ACTIONS     = ACTIONS;
  FILTER      = FILTER;
  JAIL        = JAIL;
  ACTION      = ACTION;
  CONNECTIONS = CONNECTIONS;
  SOURCES     = SOURCES;
  LOG         = LOG;
}
