FILTER{ "vssc-setup";
  enabled = false;
  source  = "vssc";
  exclude = WHITE_IP;
  hint    = "setup request from";
  engine  = "pcre";
  failregex = {
    [=[^(\d\d\d\d\-\d\d\-\d\d \d\d:\d\d:\d\d) !\d+! (?:SIP|H323) setup request from \[([0-9.]+)\] agent \[.*?\] number \[.*?\]]=];
  }
}

FILTER{ "vssc-auth-fail";
  enabled = false;
  source  = "vssc";
  exclude = WHITE_IP;
  hint    = "auth request";
  engine  = "pcre";
  failregex = {
    [=[^(\d\d\d\d\-\d\d\-\d\d \d\d:\d\d:\d\d) !\d+! (?:SIP|H323) auth request fail \S+ \[.*?\] from \[([0-9.]+)\]\[.*?\] for user \[.*?\] login \[.*?\] number \[.*?\]]=];
  }
}

FILTER{ "vssc-ip-request";
  enabled = false;
  source  = "vssc";
  exclude = WHITE_IP;
  hint    = "auth request";
  engine  = 'pcre';
  failregex = {
    [=[^(\d\d\d\d\-\d\d\-\d\d \d\d:\d\d:\d\d) !\d+! (?:SIP|H323) auth request \S+ \S+ \[(?:[^:]*:).*?@?(?:[0-9]+)\.(?:[0-9]+)\.(?:[0-9]+)\.(?:[0-9]+);?.*?\] from \[([0-9.]+)\]\[.*?\] for user \[.*?\] login \[.*?\] number \[.*?\]]=];
  }
}
