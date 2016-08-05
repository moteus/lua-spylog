ACTION{"ipsec",
  ban   = { "netsh", "ipsec static add filter filterlist=BlockList srcaddr=<HOST> dstaddr=me description=\"<DATE> <FILTER> <JAIL> <BANTIME>\""};
  unban = { "netsh", "ipsec static delete filter filterlist=BlockList srcaddr=<HOST> dstaddr=me"};
  unique = "netsh ipsec <HOST>";
  options = {
    timeout = 10000;
  }
};
