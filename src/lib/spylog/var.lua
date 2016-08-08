local Format do 

local lpeg = require "lpeg"

local P, C, Cs, Ct, Cp, S = lpeg.P, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cp, lpeg.S

local any = P(1)
local sym = any-S':}'
local esc = P'%%' / '%%'
local var = P'%{' * C(sym^1) * '}'
local fmt = P'%{' * C(sym^1) * ':' * C(sym^1) * '}'

local function LpegFormat(str, context)
  local unknown

  local function fmt_sub(k, fmt)
    local v = context[k]
    if v == nil then
      local n = tonumber(k)
      if n then v = context[n] end
    end

    if v ~= nil then
      return string.format("%"..fmt, context[k])
    end

    unknown = unknown or {}
    unknown[k] = ''
  end

  local function var_sub(k)
    local v = context[k]
    if v == nil then
      local n = tonumber(k)
      if n then v = context[n] end
    end
    if v ~= nil then
      return tostring(v)
    end
    unknown = unknown or {}
    unknown[k] = ''
  end

  local pattern = Cs((esc + (fmt / fmt_sub) + (var / var_sub) + any)^0)

  return pattern:match(str), unknown
end

local function LuaFormat(str, context)
  local unknown

  -- %{name:format}
  str = string.gsub(str, '%%%{([%w_][%w_]*)%:([-0-9%.]*[cdeEfgGiouxXsq])%}',
    function(k, fmt)
      local v = context[k]
      if v == nil then
        local n = tonumber(k)
        if n then v = context[n] end
      end

      if v ~= nil then 
        return string.format("%"..fmt, context[k])
      end
      unknown = unknown or {}
      unknown[k] = ''
    end
  )

  -- %{name}
  return str:gsub('%%%{([%w_][%w_]*)%}', function(k)
    local v = context[k]
    if v == nil then
      local n = tonumber(k)
      if n then v = context[n] end
    end
    if v ~= nil then
      return tostring(v)
    end
    unknown = unknown or {}
    unknown[k] = ''
  end), unknown
end

Format = function(str, context)
  if string.find(str, '%%', 1, true) then
    return LpegFormat(str, context)
  end
  return LuaFormat(str, context)
end

end

local combine do

local mt = {
  __index = function(self, k)
    for i = 1, #self do
      if self[i][k] ~= nil then
        return self[i][k]
      end
    end
  end
}

combine = function(t)
  return setmetatable(t, mt)
end

end

return {
  format  = Format;
  combine = combine;
}