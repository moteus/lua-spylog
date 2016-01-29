FILTER{ "rdp-fail-access";
  enabled = true;
  source  = "trap:udp://127.0.0.1";
  exclude = WHITE_IP;
  trap    = {529, 4625};
  failregex = {
    "Source Network Address:%s+([0-9.]+)";
    --cp1251
    "Адрес сети источника:%s+([0-9.]+)";
  }
};

