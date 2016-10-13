FILTER{ "fusionpbx-fail-access";
  enabled = false;
  source  = "eventlog:udp://127.0.0.1";
  exclude = WHITE_IP;
  events  = {'PHP-*', 3};
  failregex = {
    "FusionPBX %[([0-9.]+)%] authentication failed";
    "FusionPBX %[([0-9.]+)%] provision attempt bad password for";
  }
};

