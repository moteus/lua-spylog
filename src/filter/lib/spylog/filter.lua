local iputil = require "spylog.iputil"
local log = require "spylog.log"

local ENGINES = {
  default = function(filter)
    local failregex = filter.failregex
    if type(failregex) == 'string' then
      failregex = {failregex}
    end

    local match = function(t)
      if (not filter.hint) or string.find(t, filter.hint, nil, true) then
        for i = 1, #failregex do
          local dt, ip = string.match(t, failregex[i])
          if dt then return dt, ip end
        end
      end
    end

    if filter.ignoreregex then
      local ignoreregex = filter.ignoreregex
      if type(ignoreregex) == 'string' then
        ignoreregex = {ignoreregex}
      end

      local function ignore(dt, ip, ...)
        if dt then
          for i = 1, #ignoreregex do
            if string.find(t, ignoreregex[i]) then
              log.debug("[%s] match `%s` but excluded by ignoreregex", filter.name, ip)
              return
            end
          end
        end
        return dt, ip, ...
      end

      local pass = match
      match = function(t)
        return ignore(pass(t))
      end
    end

    return match
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

    local match = function(t)
      if (not filter.hint) or string.find(t, filter.hint, nil, true) then
        for i = 1, #failregex do
          local dt, ip = failregex[i]:match(t)
          if dt then return dt, ip end
        end
      end
    end

    if filter.ignoreregex then
      local ignoreregex = {}

      if type(filter.ignoreregex) == "string" then
        ignoreregex[1] = assert(rex.new(filter.ignoreregex))
      else
        for i = 1, #filter.ignoreregex do
          ignoreregex[i] = assert(rex.new(filter.ignoreregex[i]))
        end
      end

      local function ignore(dt, ip, ...)
        if dt then
          for i = 1, #ignoreregex do
            if ignoreregex[i]:find(t) then
              log.debug("[%s] match `%s` but excluded by ignoreregex", filter.name, ip)
              return
            end
          end
        end
        return dt, ip, ...
      end

      local pass = match
      match = function(t)
        return ignore(pass(t))
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
        log.debug("[%s] match `%s` but excluded by cidr", filter.name, ip)
        return
      end
      return dt, ip
    end
  end
end

return build_rex_filter