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

local function ApplyTags(str, tags, escape)
  return (string.gsub(str, '%b<>', function(tag)
    tag = string.sub(tag, 2, -2)
    tag = tags[tag] or tags[string.lower(tag)] or ''
    return escape and EscapeTag(tag) or tag
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

local function DecodeArgs(arguments, tags)
  local args, tail, err

  if type(arguments) == 'string' then
    args, tail = SplitArgs(arguments)
    if not args then return nil, tail end
  else
    args = arguments
  end

  for i = 1, #args do
    args[i] = ApplyTags(args[i], tags, false)
  end

  return args, tail
end

local function DecodeCommand(command, tags)
  local cmd, args, tail, err

  if type(command) == 'string' then
    cmd, args, tail = SplitCommand(command)
    if not cmd then err = args end
  elseif command[2] then
    cmd = command[1]
    if not cmd then
      err = 'first element have to be a commad'
    else
      if type(command[2]) == 'string' then
        args, tail = SplitArgs(command[2])
        if not args then err, cmd = tail end
      else
        args = command[2]
      end
    end
  elseif command[1] then
    cmd, args, tail = SplitCommand(command[1])
    if not cmd then err = args end
  end

  if not cmd then return nil, err end

  for i = 1, #args do
    args[i] = ApplyTags(args[i], tags, false)
  end

  return cmd, args, tail
end

return {
  build          = BuildArgs;
  split          = SplitArgs;
  split_command  = SplitCommand;
  escape_tag     = EscapeTag;
  apply_tags     = ApplyTags;
  decode         = DecodeArgs;
  decode_command = DecodeCommand;
}
