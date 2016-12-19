-- Start action:
--    netsh ipsec static delete policy name=SpyLogBlock
--    netsh ipsec static add filteraction name=SpyLogBlock action=block
--    netsh ipsec static add filter filterlist=SpyLogBlock srcaddr=192.168.192.100 dstaddr=me
--    netsh ipsec static add policy name=SpyLogBlock assign=yes activatedefaultrule=no
--    netsh ipsec static add rule name=SpyLogBlock policy=SpyLogBlock filterlist=SpyLogBlock filteraction=SpyLogBlock
--    netsh ipsec static delete filter filterlist=SpyLogBlock srcaddr=192.168.192.100 dstaddr=Me
-- Stop action:
--    netsh ipsec static delete policy name=SpyLogBlock
local args = 'filterlist=<FILTERLIST> srcaddr=<HOST> srcmask=<NET> protocol=<PROTOCOL> dstport=<PORT> dstaddr=me'
ACTION{"ipsec",
  ban   = 'netsh ipsec static add filter ' .. args .. ' description="<DATE> <FILTER> <JAIL> <BANTIME>"';

  unban = 'netsh ipsec static delete filter ' .. args;

  unique = "netsh ipsec " .. args;

  parameters = {
    filterlist = 'SpyLogBlock';
    net        = '32';
    protocol   = 'ANY';
    port       = '0';
  };

  options = {
    timeout = 10000;
  }
};
