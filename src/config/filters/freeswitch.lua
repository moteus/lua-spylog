FILTER{ "freeswitch-ip-request";
  enabled = true;
  source  = "freeswitch";
  exclude = WHITE_IP;
  hint    = "[WARNING]";
  engine  = 'pcre';
  failregex = {
    [[^(\d\d\d\d\-\d\d\-\d\d \d\d:\d\d:\d\d\.\d+) \[WARNING\] sofia_reg.c:\d+ SIP auth (?:challenge|failure) \([A-Z]+\) on sofia profile \'[^']+\' for \[.*?@\d+.\d+.\d+.\d+\] from ip ([0-9.]+)\s*$]]
  }
}

FILTER{ "freeswitch-auth-request";
  enabled = true;
  source  = "freeswitch";
  exclude = WHITE_IP;
  hint    = "[WARNING]";
  failregex = {
    "^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d+) %[WARNING%] sofia_reg.c:%d+ SIP auth challenge %([A-Z]+%) on sofia profile %'[^']+%' for %[.-%] from ip ([0-9.]+)%s*$";
  }
};

FILTER{ "freeswitch-auth-fail";
  enabled = true;
  source  = "freeswitch";
  exclude = WHITE_IP;
  hint    = "[WARNING]";
  failregex = {
    "^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d+) %[WARNING%] sofia_reg.c:%d+ SIP auth failure %([A-Z]+%) on sofia profile %'[^']+%' for %[.-%] from ip ([0-9.]+)%s*$";
    "^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d+) %[WARNING%] sofia.c:%d+ IP ([0-9.]+) Rejected by acl \"[^\"]*\"%s*$";
  }
};

