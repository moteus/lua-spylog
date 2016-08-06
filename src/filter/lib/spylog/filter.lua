local iputil = require "spylog.iputil"
local log = require "spylog.log"

local ENGINES = {
  default = function(filter)
    local failregex = filter.failregex
    if type(failregex) == 'string' then
      failregex = {failregex}
    end

    local function rmatch(i, t, ...)
      if ... then return i-1, ... end
      if failregex[i] then
        return rmatch(i+1, t, string.match(t, failregex[i]))
      end
    end

    local match = function(t)
      if (not filter.hint) or string.find(t, filter.hint, nil, true) then
        return rmatch(1, t)
      end
    end

    if filter.ignoreregex then
      local ignoreregex = filter.ignoreregex
      if type(ignoreregex) == 'string' then
        ignoreregex = {ignoreregex}
      end

      local function ignore(t, rid, dt, ip, ...)
        if dt then
          for i = 1, #ignoreregex do
            if string.find(t, ignoreregex[i]) then
              log.debug("[%s] match `%s` but excluded by ignoreregex", filter.name, ip)
              return
            end
          end
        end
        return rid, dt, ip, ...
      end

      local pass = match
      match = function(t)
        return ignore(t, pass(t))
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

    local function rmatch(i, t, ...)
      if ... then return i-1, ... end
      if failregex[i] then
        return rmatch(i+1, t, failregex[i]:match(t))
      end
    end

    local match = function(t)
      if (not filter.hint) or string.find(t, filter.hint, nil, true) then
        return rmatch(1, t)
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

      local function ignore(t, rid, dt, ip, ...)
        if rid then
          for i = 1, #ignoreregex do
            if ignoreregex[i]:find(t) then
              log.debug("[%s] match `%s` but excluded by ignoreregex", filter.name, ip or dt)
              return
            end
          end
        end
        return rid, dt, ip, ...
      end

      local pass = match
      match = function(t)
        return ignore(t, pass(t))
      end
    end

    return match
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

  search_fn = search_fn or assert(engine(filter), "Internal error while build filter: " .. filter.name .. " engine: " .. (filter.engine or 'default') )
  local exclude_cidr = iputil.load_cidrs(filter.exclude or {})

  local result
  if filter.capture then
    local captures = filter.capture

    if type(captures[1]) ~= 'table' then
      captures = {captures}
    end

    local failregex = type(filter.failregex) == 'string' and {filter.failregex} or filter.failregex

    for i = 1, #captures do assert(failregex[i], 'No regex for capture #' .. i) end
    for i = 1, #failregex do assert(captures[i], 'No capture for regex #' .. i) end

    result = function(rid, ...)
      if not rid then return end
      local capture, result = captures[rid], {}
      for i = 1, #capture do
        local name = capture[i]
        result[name] = select(i, ...)
      end

      if not result.date then result.date = os.date("%Y-%m-%d %H:%M:%S") end

      if result.host and iputil.find_cidr(result.host, exclude_cidr) then
        log.debug("[%s] match `%s` but excluded by cidr", filter.name, result.host)
        return
      end

      return result
    end
  else
    result = function(rid, dt, ip)
      if not rid then return end
      if not ip then ip, dt = dt, os.date("%Y-%m-%d %H:%M:%S") end
      if iputil.find_cidr(ip, exclude_cidr) then
        log.debug("[%s] match `%s` but excluded by cidr", filter.name, ip)
        return
      end
      return dt, ip
    end
  end

  return function(t)
    return result(search_fn(t))
  end
end

return build_rex_filter