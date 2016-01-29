ACTION{"advfirewall",
  on  = { "netsh", 'advfirewall firewall add rule name="<UUID>" dir=in interface=any action=block remoteip=<HOST>'};
  off = { "netsh", 'advfirewall firewall delete rule name="<UUID>"' };
  options = {
    timeout = 10000;
  }
}
