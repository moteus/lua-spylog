-- Start action:
--    netsh ipsec static delete policy name=Block
--    netsh ipsec static add filteraction name=Block action=block
--    netsh ipsec static add filter filterlist=BlockList srcaddr=192.168.192.100 dstaddr=me
--    netsh ipsec static add policy name=Block assign=yes activatedefaultrule=no
--    netsh ipsec static add rule name=BlockList policy=Block filterlist=BlockList filteraction=Block
--    netsh ipsec static delete filter filterlist=BlockList srcaddr=192.168.192.100 dstaddr=Me
-- Stop action:
--    netsh ipsec static delete policy name=Block
ACTION{"ipsec",
  ban   = 'netsh ipsec static add filter filterlist=BlockList srcaddr=<HOST> dstaddr=me description="<DATE> <FILTER> <JAIL> <BANTIME>"';

  unban = 'netsh ipsec static delete filter filterlist=BlockList srcaddr=<HOST> dstaddr=me';

  unique = "netsh ipsec <HOST>";

  options = {
    timeout = 10000;
  }
};
