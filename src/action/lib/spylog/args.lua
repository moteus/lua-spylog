local lpeg = require 'lpeg'

local function MakeArgsGramma(sep, quot)
  assert(#sep == 1 and #quot == 1)
  local P, C, Cs, Ct, Cp = lpeg.P, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cp
  local nl         = P('\n')
  local any        = P(1)
  local eos        = P(-1)
  local nonescaped = C((any - (nl + P(quot) + P(sep) + P('=') + eos))^0)
  local escaped    = P(quot) * Cs((((any - P(quot)) + (P(quot) * P(quot)) / quot))^0) * P(quot)
  local escaped2   = Ct(nonescaped * '=' * (escaped+nonescaped))
  local field      = escaped + escaped2 + nonescaped
  local record     = Ct(field * ( P(sep) * field )^0) * (nl + eos) * Cp()
  return record
end

local function Split(str, pat)
  local t, pos = pat:match(str)
  if pos ~= nil then
    str = str:sub(pos)
  end

  local r = {}
  if t then
    for i = 1, #t do
      if type(t[i]) == 'table' then
        r[ #r+1 ] = t[i][1] .. '=' .. t[i][2] .. ''
      elseif t[i] ~= '' then
        r[#r+1] = t[i]
      end
    end
  end

  if str == '' then
    str = nil
  end

  return r, str
end

local pattern = MakeArgsGramma(' ', '"')

local function SplitArgs(cmd)
  local args, tail = Split(cmd, pattern)
  if not args then
    return nil, "can not parse command: " .. cmd
  end

  return args, tail
end

local function SplitCommand(cmd)
  local args, tail = SplitArgs(cmd, pattern)
  if (not args) or (#args == 0) then
    return nil, "can not parse command: " .. cmd
  end
  return table.remove(args, 1), args, tail
end

local function EscapeTag(str)
  str = tostring(str)
  return (string.gsub(str,'"', '""'))
end

local function ApplyTags(str, tags)
  return (str:gsub('%b<>', function(tag)
    tag = tag:sub(2,-2)
    return EscapeTag(tags[tag] or tags[tag:lower()] or '')
  end))
end

local function BuildArgs(args)
  local s
  for _, a in ipairs(args) do
    if s then s = s .. ' ' else s = '' end
    a = (a):gsub('"', '""')
    if a:find("%s") then a = '"' .. a .. '"' end
    s = s .. a
  end
  return s
end

return {
  build         = BuildArgs;
  split         = SplitArgs;
  split_command = SplitCommand;
  escape_tag    = EscapeTag;
  apply_tags    = ApplyTags;
}
