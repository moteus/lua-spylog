-- Start action:
--    netsh ipsec static delete policy name=SpyLogBlock
--    netsh ipsec static add filteraction name=SpyLogBlock action=block
--    netsh ipsec static add filter filterlist=SpyLogBlock srcaddr=192.168.192.100 dstaddr=me
--    netsh ipsec static add policy name=SpyLogBlock assign=yes activatedefaultrule=no
--    netsh ipsec static add rule name=SpyLogBlock policy=SpyLogBlock filterlist=SpyLogBlock filteraction=SpyLogBlock
--    netsh ipsec static delete filter filterlist=SpyLogBlock srcaddr=192.168.192.100 dstaddr=Me
-- Stop action:
--    netsh ipsec static delete policy name=SpyLogBlock
ACTION{"ipsec",
  ban   = 'netsh ipsec static add filter filterlist=<FILTERLIST> srcaddr=<HOST> srcmask=<NET> dstaddr=me description="<DATE> <FILTER> <JAIL> <BANTIME>"';

  unban = 'netsh ipsec static delete filter filterlist=<FILTERLIST> srcaddr=<HOST> srcmask=<NET> dstaddr=me';

  unique = "netsh ipsec <HOST>";

  parameters = {
    filterlist = 'SpyLogBlock';
    net        = '32';
  };

  options = {
    timeout = 10000;
  }
};
