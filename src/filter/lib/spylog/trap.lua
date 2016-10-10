local ut  = require "lluv.utils"
local bit = require "bit32"

local function bin2hex(str)
  local t = {string.byte(str, 1, #str)}
  for i = 1, #t do t[i] = string.format('%.2X', t[i]) end
  return table.concat(t)
end

local function hex2bin(str)
  str = str:gsub("(..)", function(ch)
    local a = tonumber(ch, 16)
    return string.char(a)
  end)
  return str
end

-- some libs convert to signed integer
local unsigned_bit = (0xFFFFFFFF == bit.bor(0xFFFFFFFF, 0x0)) and 4 or 2

local function to_unsigned(v)
  local n = #v

  if n == 1 then
    return (string.byte(v))
  end

  local value = 0
  if n <= unsigned_bit then
    for i = 1, n do
      value = bit.bor(bit.lshift(value, 8), string.byte(v, i))
    end
  else
    for i = 1, n do
      value = value + (256 ^ (n-i)) * string.byte(v, i)
    end
  end
  return value
end

local function to_signed(v)
  local sign = (bit.band(string.byte(v, 1), 0x80) == 0)
  value = to_unsigned(v)
  if not sign then
    value = value - 256^#v
  end
  return value
end

-- assert(0xAB          == to_unsigned(hex2bin"AB"))
-- assert(0xABCD        == to_unsigned(hex2bin"ABCD"))
-- assert(0xABCDEF      == to_unsigned(hex2bin"ABCDEF"))
-- assert(0xFFABCDEF    == to_unsigned(hex2bin"FFABCDEF"))
-- assert(1098099060735 == to_unsigned(hex2bin"FFABCDEFFF"))

-- assert(  0  == to_signed(hex2bin"00"))
-- assert( 127 == to_signed(hex2bin"7F"))
-- assert( 128 == to_signed(hex2bin"0080"))
-- assert( 256 == to_signed(hex2bin"0100"))
-- assert(-128 == to_signed(hex2bin"80"))
-- assert(-129 == to_signed(hex2bin"FF7F"))

local BinIter = ut.class() do

function BinIter:__init(s)
  assert(type(s) == "string")

  self._s = s
  self._i = 1
  return self
end

function BinIter:rest()
  if self._i > #self._s then return 0 end
  return #self._s - self._i + 1
end

function BinIter:peek_char(n)
  n = n or 1
  return self._s:sub(self._i, self._i + n - 1)
end

function BinIter:read_char(n)
  local s = self:peek_char(n)
  self._i = self._i + #s
  return s
end

function BinIter:peek_byte()
  return string.byte(self:peek_char(), 1)
end

function BinIter:read_byte()
  return string.byte(self:read_char(), 1)
end

function BinIter:read_str(n)
  return self:read_char(n)
end

function BinIter:read_unsigned(n)
  return to_unsigned(self:read_char(n))
end

function BinIter:read_signed(n)
  return to_signed(self:read_char(n))
end

end

local function oid_node(iter)
  local n = 0
  repeat
    local octet = iter:read_byte()
    n = n * 128 + bit.band(0x7F, octet)
  until octet < 128

  return n
end

local decode
local decoders = {
  -- Boolean
  [0x01] = function( iter, len )
    local val = iter:read_byte()
    return val ~= 0xFF
  end;

  -- Integer
  [0x02] = function( iter, len )
    return iter:read_signed(len)
  end;

  -- Octet String
  [0x04] = function( iter, len )
    return iter:read_str(len)
  end;

  -- Null
  [0x05] = function( iter, len )
    return false
  end;

  -- Object Identifier
  [0x06] = function( iter, len )
    local oid = {}
    local str = iter:read_char(len)
    iter = BinIter.new(str)

    if iter:rest() > 0 then
      local b = iter:read_byte()
      oid[2] = math.fmod(b, 40)
      b = b - oid[2]
      oid[1] = math.floor(b/40 + 0.1)
    end

    while iter:rest() > 0 do
      local c = oid_node(iter)
      oid[#oid + 1] = c
    end

    return oid

  end;

  -- Context specific tags
  [0x30] = function( iter, len )
    local seq = {}
    local hex = iter:read_char(len)
    iter = BinIter.new(hex)
    while iter:rest() > 0 do
      local value = decode(iter)
      seq[#seq + 1] = value
    end
    return seq
  end;
}

local function decode_unsigned(iter, len)
  return iter:read_unsigned(len)
end

decoders[0x40] = decoders[0x04]   -- IP Address; 4 byte IPv4
decoders[0x41] = decode_unsigned  -- Counter; same as Integer
decoders[0x42] = decoders[0x02]   -- Gauge
decoders[0x43] = decode_unsigned  -- TimeTicks
decoders[0x44] = decoders[0x04]   -- Opaque; same as Octet String
decoders[0x45] = decoders[0x06]   -- NsapAddress
decoders[0x46] = decode_unsigned  -- Counter64
decoders[0x47] = decode_unsigned  -- UInteger32

-- Context specific tags
decoders[0xA0] = decoders[0x30]   -- GetRequest-PDU
decoders[0xA1] = decoders[0x30]   -- GetNextRequest-PDU
decoders[0xA2] = decoders[0x30]   -- Response-PDU
decoders[0xA3] = decoders[0x30]   -- SetRequest-PDU
decoders[0xA4] = decoders[0x30]   -- Trap-PDU
decoders[0xA5] = decoders[0x30]   -- GetBulkRequest-PDU
decoders[0xA6] = decoders[0x30]   -- InformRequest-PDU (not implemented here yet)
decoders[0xA7] = decoders[0x30]   -- SNMPv2-Trap-PDU (not implemented here yet)

local function read_length(iter)
  local len = iter:read_byte()
  if len > 128 then
    local size = len - 128
    len = 0
    for i = 1, size do
      len = len * 256 + iter:read_byte()
    end
  end
  return len
end

local function read_header(iter)
  local typ = iter:read_byte()
  local len = read_length(iter)
  return typ, len
end

function decode(iter)
  local typ, len = read_header(iter)
  local decoder = decoders[typ]
  if decoder then
    return decoder(iter, len)
  end
end

local function trap_decode(str)
  local iter = BinIter.new(str)
  local t = decode(iter)
  if not t then return nil end
  local p = {}

  if type(t[1]) ~= "number" then return end
  p.version    = t[1] + 1
  if p.version <= 0 or p.version > 3 then return end

  if type(t[2]) ~= "string" then return end
  p.community  = t[2]

  if type(t[3]) ~= "table" then return end
  local pdu    = t[3]

  if type(pdu[1]) ~= "table" then return end
  p.enterprise = table.concat(pdu[1], ".")

  if type(pdu[2]) ~= "string" then return end
  p.agent     = table.concat({string.byte(pdu[2], 1, #pdu[2])}, '.')

  if type(pdu[3]) ~= "number" then return end
  if pdu[3] < 0 or pdu[3] > 6 then return end
  p.generic       = pdu[3]

  if type(pdu[4]) ~= "number" then return end
  p.specific       = pdu[4]

  if type(pdu[5]) ~= "number" then return end
  p.time       = pdu[5]

  if type(pdu[6]) ~= "table" then return end

  for i = 1, #pdu[6] do
    local msg = pdu[6][i]
    if type(msg) ~= "table" or type(msg[1]) ~= "table" then return end
    msg[1] = table.concat(msg[1], ".")
  end

  p.data = pdu[6]

  return p
end

local function trap_print(t)
  print("Version:",    t.version)
  print("Community:",  t.community)
  print("Enterprise:", t.enterprise)
  print("Agent:",      t.agent)
  print("Generic:",    t.generic)
  print("Specific:",   t.specific)
  print("Time:",       t.time)
  print("Data:")
  for i = 1, #t.data do
    print("", t.data[i][1])
    print("", t.data[i][2])
    print("------------------")
  end
end

-------------------------------------------------------------------------------
local trap2eventlog do

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

local eventlog_levels = {
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

-- MS specific OID
local EventLogOID = '1.3.6.1.4.1.311.1.13.1.'

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
  -- But other bits still unknown
  -- 

  local id  = bit.band(0xFFFF, v)
  local lvl = eventlog_levels[bit.rshift(v, 30)]

  return id, lvl
end

trap2eventlog = function(t)
  if not t.enterprise then return end

  local name, value = decode_event_log_oid(t.enterprise)
  if name ~= 'source' then return end

  -- I am not sure why but I get `-2147483645` for event id `3`
  local EventID, Level = Specific2EventID(t.specific)

  local event = {
    id         = EventID;
    severity   = Level;
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

end
-------------------------------------------------------------------------------
require "pp"(
  trap2eventlog(
    trap_decode(
      hex2bin(
        '3082014E020100040770726976617465A482013E06152B060104018237010D010A5048502D352E332E323940047F00000102010602048000000343037B10683082010F304C060E2B060104018237010D01CE0F0100043A467573696F6E504258205B3139322E3136382E3132332E36305D2061757468656E7469636174696F6E206661696C656420666F72203130340D0A3019060E2B060104018237010D01CE0F02000407556E6B6E6F776E301B060E2B060104018237010D01CE0F03000409616C657865792D50433013060E2B060104018237010D01CE0F04000401323013060E2B060104018237010D01CE0F0500040135301B060E2B060104018237010D01CE0F06000409467573696F6E5042583040060E2B060104018237010D01CE0F0700042E5B3139322E3136382E3132332E36305D2061757468656E7469636174696F6E206661696C656420666F7220313034'
      )
    )
  )
)

require "pp"(
  trap2eventlog(
    trap_decode(
      hex2bin(
        '3082040102010004067075626C6963A48203F206132B060104018237010D0108536563757269747940047F00000102010602020211430403839452308203C6308201FB060E2B060104018237010D01CE0F0100048201E7D1E1EEE920E2F5EEE4E020E220F1E8F1F2E5ECF33A0D0A0D0A09CFF0E8F7E8EDE03A09EDE5E8E7E2E5F1F2EDEEE520E8ECFF20EFEEEBFCE7EEE2E0F2E5EBFF20E8EBE820EDE5E2E5F0EDFBE920EFE0F0EEEBFC0D0A0D0A09CFEEEBFCE7EEE2E0F2E5EBFC3A09C0E4ECE8EDE8F1F2F0E0F2EEF00D0A0D0A09C4EEECE5ED3A0909465245455357495443480D0A0D0A09D2E8EF20E2F5EEE4E03A09370D0A0D0A09CFF0EEF6E5F1F120E2F5EEE4E03A0955736572333220200D0A0D0A09CFE0EAE5F220EFF0EEE2E5F0EAE83A094E65676F74696174650D0A0D0A09D0E0E1EEF7E0FF20F1F2E0EDF6E8FF3A09465245455357495443480D0A0D0A09C8ECFF20E2FBE7FBE2E0FEF9E5E3EE20EFEEEBFCE7EEE2E0F2E5EBFF3A0946524545535749544348240D0A0D0A09C4EEECE5ED20E2FBE7FBE2E0FEF9E5E3EE3A09574F524B47524F55500D0A0D0A09CAEEE420E2F5EEE4E020E2FBE7FBE2E0FEF9E5E3EE3A09283078302C3078334537290D0A0D0A09CAEEE420EFF0EEF6E5F1F1E020E2FBE7FBE2E0FEF9E5E3EE3A093337360D0A0D0A09CFF0EEECE5E6F3F2EEF7EDFBE520F1EBF3E6E1FB3A092D0D0A0D0A09C0E4F0E5F120F1E5F2E820E8F1F2EEF7EDE8EAE03A093132372E302E302E310D0A0D0A09CFEEF0F220E8F1F2EEF7EDE8EAE03A09300D0A0D0A3018060E2B060104018237010D01CE0F0200040653595354454D301C060E2B060104018237010D01CE0F0300040A465245455357495443483014060E2B060104018237010D01CE0F0400040231363013060E2B060104018237010D01CE0F0500040132301F060E2B060104018237010D01CE0F0600040DC0E4ECE8EDE8F1F2F0E0F2EEF0301C060E2B060104018237010D01CE0F0700040A465245455357495443483013060E2B060104018237010D01CE0F0800040137301A060E2B060104018237010D01CE0F090004085573657233322020301B060E2B060104018237010D01CE0F0A0004094E65676F7469617465301C060E2B060104018237010D01CE0F0B00040A46524545535749544348301D060E2B060104018237010D01CE0F0C00040B4652454553574954434824301B060E2B060104018237010D01CE0F0D000409574F524B47524F5550301D060E2B060104018237010D01CE0F0E00040B283078302C3078334537293015060E2B060104018237010D01CE0F0F0004033337363013060E2B060104018237010D01CE0F100004012D301B060E2B060104018237010D01CE0F110004093132372E302E302E313013060E2B060104018237010D01CE0F1200040130'
      )
    )
  )
)
return {
  decode_hex = function(str)
    return trap_decode(hex2bin(str))
  end;

  decode = function(str)
    return trap_decode(str)
  end;

  decode_eventlog = function(str)
    local trap, err = trap_decode(str)
    if not trap then return nil, err end
    return trap2eventlog(trap)
  end;

  bin2hex = bin2hex;

  print  = trap_print;
}
