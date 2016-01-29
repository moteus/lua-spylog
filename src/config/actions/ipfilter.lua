ACTION{"ipfilter",
  on  = { [[c:\ipf\ipfilter.exe]], "blacklistadd=<HOST>,255.255.255.255,<JAIL>"};
  off = { [[c:\ipf\ipfilter.exe]], "blacklistremove=<HOST>,255.255.255.255" };
  unique = "ipfilter <HOST>";
  options = {
    timeout = 10000;
  }
}
