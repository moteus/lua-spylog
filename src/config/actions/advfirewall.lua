ACTION{"advfirewall",
  ban   = { "netsh", 'advfirewall firewall add rule name="<UUID>" dir=in interface=any action=block remoteip=<HOST>'};
  unban = { "netsh", 'advfirewall firewall delete rule name="<UUID>"' };
  options = {
    timeout = 10000;
  }
}
