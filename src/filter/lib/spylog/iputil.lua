local bit = require "bit32"

local masks = {
  "128.0.0.0",
  "192.0.0.0",
  "224.0.0.0",
  "240.0.0.0",
  "248.0.0.0",
  "252.0.0.0",
  "254.0.0.0",
  "255.0.0.0",
  "255.128.0.0",

  "255.192.0.0",
  "255.224.0.0",
  "255.240.0.0",
  "255.248.0.0",
  "255.252.0.0",
  "255.254.0.0",
  "255.255.0.0",

  "255.255.128.0",
  "255.255.192.0",
  "255.255.224.0",
  "255.255.240.0",
  "255.255.248.0",
  "255.255.252.0",
  "255.255.254.0",

  "255.255.255.0",
  "255.255.255.128",
  "255.255.255.192",
  "255.255.255.224",
  "255.255.255.240",
  "255.255.255.248",
  "255.255.255.252",
  "255.255.255.254",
  "255.255.255.255"
}

local bin_mask, bin_not_mask = {}, {}

local function ip2octets(s)
  local a, b, c, d = string.match(s, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  a,b,c,d = tonumber(a),tonumber(b),tonumber(c),tonumber(d)
  if not a then return end
  if a > 255 or b > 255 or c > 255 or d > 255 then
    return
  end
  return a, b, c, d
end

local function ip2int(s)
  local a, b, c, d = ip2octets(s)
  if not a then return end
  return a * (256 ^ 3) + b * (256 ^ 2) + c * (256 ^ 1) + d
end

local tmp = {}
local function int2ip(s)
  if s < 0 or s > 0xFFFFFFFF then
    return
  end

  for i = 4,1,-1 do
    tmp[i] = math.mod(s, 256);
    s = math.floor( s / 256 );
  end
  return table.concat(tmp, '.')
end

for i = 1, #masks do
  bin_mask[i] = ip2int(masks[i])
  bin_not_mask[i] = 0xFFFFFFFF - bin_mask[i]

  bin_mask[tostring(i)] = bin_mask[i]
  bin_not_mask[tostring(i)] = bin_not_mask[i]
end

local function cidr2range(s)
  local a, b, c, d, cidr = string.match(s, "^(%d+)%.(%d+)%.(%d+)%.(%d+)/(%d+)$")
  a,b,c,d = tonumber(a),tonumber(b),tonumber(c),tonumber(d)
  if not a then return end
  if a > 255 or b > 255 or c > 255 or d > 255 then
    return
  end
  local mask, not_mask = bin_mask[cidr], bin_not_mask[cidr]
  if not mask then
    return
  end
  local net = a * (256 ^ 3) + b * (256 ^ 2) + c * (256 ^ 1) + d

  local low, hi = bit.band(net, mask), bit.bor(net, not_mask)
  return low, hi
end

local function load_cidrs(s)
  local t = {ip={}}

  for i = 1, #s do
    local ip = ip2int(s[i])
    if ip then t.ip[s[i]] = true
    else
      local low, hi = cidr2range(s[i])
      if low then
        t[#t+1] = {low, hi, s[i]}
      end
    end
  end

  table.sort(t, function(lhs, rhs)
    if lhs[1] == rhs[1] then
      return lhs[2] < rhs[2]
    end
    return lhs[1] < rhs[1]
  end)

  return t
end

local function find_cidr(ip, s)
  if s.ip[ip] then return ip end

  local bin, i, n = ip2int(ip), 1, #s
  if bin then
    while (i <= n) and (bin >= s[i][1]) do
      if bin <= s[i][2] then return s[i][3] end
      i = i + 1
    end
  end
end

local function cidr2mask(s)
  local ip = cidr2range(s)
  if not ip then return end
  local cidr = string.match(s, "^%d+%.%d+%.%d+%.%d+/(%d+)$")
  return int2ip(ip), masks[tonumber(cidr)]
end

return {
  load_cidrs = load_cidrs;
  cidr2mask  = cidr2mask;
  cidr2range = cidr2mask;
  ip2int     = ip2int;
  int2ip     = int2ip;
  find_cidr  = find_cidr;
}