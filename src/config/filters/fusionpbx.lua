FILTER{ "fusionpbx-fail-access";
  enabled = true;
  source  = "trap:udp://127.0.0.1";
  exclude = WHITE_IP;
  trap    = '1.3.6.1.4.1.311.1.13.1.9.80.72.80.45.53.46.51.46.56';
  failregex = {
    "FusionPBX %[([0-9.]+)%] authentication failed";
    "FusionPBX %[([0-9.]+)%] provision attempt bad password for";
  }
};

