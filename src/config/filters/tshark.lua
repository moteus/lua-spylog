FILTER{ "tshark-sip-options";
  enabled   = false;
  source    = 'tshark-sip-options';
  exclude   = WHITE_IP;
  failregex = '^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d+)\t([0-9.]+)';
}

FILTER{ "tshark-sip-ip-request";
  enabled   = false;
  source    = 'tshark-sip-request';
  exclude   = WHITE_IP;
  engine    = 'pcre';
  failregex = [[^(\d\d\d\d\-\d\d\-\d\d \d\d:\d\d:\d\d\.\d+)\t([0-9.]+)\t(?:REGISTER|INVITE|OPTIONS)\t[0-9.]+\t\d+\.\d+\.\d+\.\d+\t]]
}


