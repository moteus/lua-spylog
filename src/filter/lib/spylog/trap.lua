local ut  = require "lluv.utils"
local bit = require "bit32"

local trap_generic = {
  [0] = 'coldStart',
  [1] = 'warmStart',
  [2] = 'linkDown',
  [3] = 'linkUp',
  [4] = 'authenticationFailure',
  [5] = 'egpNeighborLoss',
  [6] = 'enterpriseSpecific'
}

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
  print("Generic:",    (t.generic and trap_generic[t.generic] or 'Unknown') .. '(' .. tostring(t.generic) .. ')')
  print("Specific:",   t.specific)
  print("Time:",       t.time)
  print("Data:")
  for i = 1, #t.data do
    print("", t.data[i][1])
    print("", t.data[i][2])
    print("------------------")
  end
end

return {
  decode_hex = function(str)
    return trap_decode(hex2bin(str))
  end;

  decode = function(str)
    return trap_decode(str)
  end;

  bin2hex = bin2hex;

  print  = trap_print;
}
