ACTION{"ipsec",
  on  = { "netsh", "ipsec static add filter filterlist=BlockList srcaddr=<HOST> dstaddr=me"};
  off = { "netsh", "ipsec static delete filter filterlist=BlockList srcaddr=<HOST> dstaddr=me"};
  unique = "netsh ipsec <HOST>";
  options = {
    timeout = 10000;
  }
};
