local iputil = require "spylog.iputil"
local log = require "spylog.log"

local ENGINES = {
  default = function(filter)
    local failregex = filter.failregex
    if type(failregex) == 'string' then
      failregex = {failregex}
    end

    return function(t)
      for i = 1, #failregex do
        if (not filter.hint) or string.find(t, filter.hint, nil, true) then
          local dt, ip = string.match(t, failregex[i])
          if dt then return dt, ip end
        end
      end
    end
  end;

  pcre = function(filter)
    local rex = require "rex_pcre"
    local failregex = {}

    if type(filter.failregex) == "string" then
      failregex[1] = assert(rex.new(filter.failregex))
    else
      for i = 1, #filter.failregex do
        failregex[i] = assert(rex.new(filter.failregex[i]))
      end
    end

    return function(t)
      for i = 1, #failregex do
        if (not filter.hint) or string.find(t, filter.hint, nil, true) then
          local dt, ip = failregex[i]:match(t)
          if dt then return dt, ip end
        end
      end
    end
  end;
}

local function build_rex_filter(filter)
  local engine = ENGINES.default

  local search_fn

  if filter.engine then
    if type(filter.engine) == 'string' then
      engine = assert(ENGINES[filter.engine], "Unknown engine: " .. filter.engine)
    elseif type(filter.engine) == 'function' then
      search_fn = filter.engine
    end
  end

  search_fn = search_fn or engine(filter)
  local exclude_cidr = iputil.load_cidrs(filter.exclude or {})

  return function(t)
    local dt, ip = search_fn(t)
    if dt then
      if not ip then ip, dt = dt, os.date("%Y-%m-%d %H:%M:%S") end
      if iputil.find_cidr(ip, exclude_cidr) then
        log.debug("[%s] match `%s` but excluded", filter.name, ip)
        return
      end
      return dt, ip
    end
  end
end

return build_rex_filter