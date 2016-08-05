ACTION{"ipfilter",
  ban   = { [[c:\ipf\ipfilter.exe]], "blacklistadd=<HOST>,255.255.255.255,<JAIL>"};
  unban = { [[c:\ipf\ipfilter.exe]], "blacklistremove=<HOST>,255.255.255.255" };
  unique = "ipfilter <HOST>";
  options = {
    timeout = 10000;
  }
}
