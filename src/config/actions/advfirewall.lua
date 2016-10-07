-- 
-- https://technet.microsoft.com/en-us/library/dd734783(v=ws.10).aspx
-- protocol = { any | Integer | icmpv4 | icmpv6 | icmpv4:type,code | icmpv6:type,code | tcp | udp }
-- Windows 7 does not support multiple protocol
--
-- port = { any | Integer | rpc | rpc-epmap | teredo | [ ,... ] }
--
-- You have to set `protocol` if you whant ban specific port.
--
-- Example bun ports 5060 and 5080 for tcp and udp
-- action = {
--  {"advfirewall", {port = "5060,5080"; protocol = "udp"}};
--  {"advfirewall", {port = "5060,5080"; protocol = "tcp"}};
-- }
--

local unban = 'netsh advfirewall firewall delete rule name="SpyLog <UUID>"'
local ban   = 'netsh advfirewall firewall add rule dir=in interface=any action=block ' ..
              'name="SpyLog <UUID>" description="<DATE> <FILTER> <JAIL> <BANTIME>" '   ..
              'remoteip="<HOST>/<NET>" localport="<PORT>" protocol="<PROTOCOL>" ';

local param = {
  net      = '32';
  port     = 'any';
  protocol = 'any';
  service  = 'any';
}

ACTION{"advfirewall",
  ban        = ban;
  unban      = unban;
  parameters = param;
  options    = { timeout = 10000 };
}

-- `program` parameter has no default value and can not be empty
ACTION{"advfirewall-program",
  ban        = ban .. ' program="<PROGRAM>"';
  unban      = unban;
  parameters = param;
  options    = { timeout = 10000 };
}

-- `service=any` means that rule will be apply only to services but not to regular application
ACTION{"advfirewall-service",
  ban        = ban .. ' service="<SERVICE>"';
  unban      = unban;
  parameters = param;
  options    = { timeout = 10000 };
}

ACTION{"advfirewall-program-service",
  ban        = ban .. ' program="<PROGRAM>" service="<SERVICE>"';
  unban      = unban;
  parameters = param;
  options    = { timeout = 10000 };
}
