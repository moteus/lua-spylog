-- Decode MS EventLog traps.

local bit = require "bit32"

local EventLog = {}

local EventLogOID = '1.3.6.1.4.1.311.1.13.1.'

local EventLogTextOID = EventLogOID .. '9999.1'

local EventLogTextOID_ = EventLogTextOID .. '.'

local eventlog_fields = {
  [ '1'  ] = 'text';
  [ '2'  ] = 'userId';
  [ '3'  ] = 'system';
  [ '4'  ] = 'type';
  [ '5'  ] = 'category';
  -- [ '6'  ] = 'var1';
  -- [ '7'  ] = 'var2';
  -- [ '8'  ] = 'var3';
  -- [ '9'  ] = 'var4';
  -- [ '10' ] = 'var5';
  -- [ '11' ] = 'var6';
  -- [ '12' ] = 'var7';
  -- [ '13' ] = 'var8';
  -- [ '14' ] = 'var9';
  -- [ '15' ] = 'var10';
  -- [ '16' ] = 'var11';
  -- [ '17' ] = 'var12';
  -- [ '18' ] = 'var13';
  -- [ '19' ] = 'var14';
  -- [ '20' ] = 'var15';
}

local eventlog_severity = {
  [0] = 'Success';
  [1] = 'Informational';
  [2] = 'Warning';
  [3] = 'Error';
}

local eventlog_types = {
  ['1' ] = 'Error';
  ['2' ] = 'Warning';
  ['4' ] = 'Informational';
  ['8' ] = 'Success Audit';
  ['16'] = 'Failure Audit';
}

local function decode_event_log_oid(str)
  if string.find(str, EventLogOID, nil, true) ~= 1 then
    return
  end

  str = string.sub(str, #EventLogOID + 1)

  local id, data = string.match(str, '^(%d+)(%.[%d%.]+)$')

  if id == '9999' then
    id, data = string.match(data, '^%.(%d+)(%.[%d%.]+)$')
    local name = eventlog_fields[id]
    if name then return name, data end
  else
    -- https://support.microsoft.com/en-us/kb/318464
    local len = tonumber(id)
    local pat = "^(" .. ("%.%d+"):rep(len) .. ")(.*)$"
    str, data = string.match(data, pat)
    if str then
      str = string.gsub(str, "(%.)(%d+)", function(_, ch)
        return string.char(tonumber(ch))
      end)
      return 'source', str, data
    end
  end
end

local function Specific2EventID(v)
  -- https://support.microsoft.com/en-us/kb/160969
  -- Low 16 bits is Event ID.
  -- Hi 2 bits is default severity.
  --
  -- But other bits stil unknown.
  -- Also MS send this value as signed integer so it
  -- not match to value from evntwin `Trap Specific ID`
  -- E.g. Trap Specific ID `2147483651` converts to `-2147483645`
  --

  local id = bit.band(0xFFFF, v)
  local severity = eventlog_severity[bit.rshift(v, 30)]

  return id, severity
end

EventLog.trap2event = function(t)
  if not t.enterprise then return end

  local name, value = decode_event_log_oid(t.enterprise)
  if name ~= 'source' then return end

  -- In threory we also should test t.generic==6.
  -- In other cases it not valid.
  local EventID, Severity = Specific2EventID(t.specific)

  local event = {
    id         = EventID;
    severity   = Severity;
    source     = value;
    agent      = t.agent;
    time       = t.time;
    -- do not use
    -- _community = t.community;
    -- _generic   = t.generic;
    -- _specific  = t.specific;
  }

  for i = 1, #t.data do
    local name, rest = decode_event_log_oid(t.data[i][1])
    if name then event[name] = t.data[i][2] end
  end

  -- e.g. for 529
  -- event.severity='Success'
  -- event.type='Failure Audit'
  -- so I think `type` is more accurate

  event.type = event.type and eventlog_types[event.type] or event.type

  return event
end

local function SourceFilter(source)
  local equal = string.sub(source, -1) ~= '*'
  if not equal then source = string.sub(source, 1, -2) end

  if not equal then
    source = "^" .. string.gsub(EventLogOID, "%.", "%%.") .. "%d+" .. string.gsub(source, '.', function(ch)
      return '%.' .. tostring(string.byte(ch))
    end) .. "%.[%.%d]+$"
  else
    source = EventLogOID .. string.format("%d", #source) .. string.gsub(source, '.', function(ch)
      return '.' .. tostring(string.byte(ch))
    end)
  end

  if equal then
    return function(t) return t.enterprise == source end
  end

  return function(t) return string.find(t.enterprise, source) end
end

local function EventIDFilter(id)
  local set = {}
  if type(id) ~= 'table' then set[id] = true else
    for k, v in ipairs(id) do set[v] = true end
  end
  return function(t) return set[bit.band(0xFFFF, t.specific)] end
end

local function SeverityFilter(id)
  local set = {}
  if type(id) ~= 'table' then set[id] = true else
    for k, v in ipairs(id) do set[v] = true end
  end
  return function(t) return set[bit.rshift(t.specific, 32)] end
end

EventLog.BuildFilter = function(t)
  if type(t[1]) == 'string' then t = {t} end

  local f = {} for _, v in ipairs(t) do
    assert(type(v[1]) == 'string', 'source name required')

    local source = SourceFilter(v[1])
    local id = v[2] and EventIDFilter(v[2])

    if not id then  f[#f+1] = function(t) return source(t) and id(t) end
    else f[#f+1] = source end
  end

  return function(t)
    for i = 1, #f do
      if f[i](t) then return true end
    end
  end
end

EventLog.trap2text = function(t)
  for i = 1, #t.data do
    local oid = t.data[i][1]
    if (string.find(oid, EventLogTextOID_, nil, true) == 1) or (EventLogTextOID == oid) then
      return t.data[i][2]
    end
  end
end

return EventLog