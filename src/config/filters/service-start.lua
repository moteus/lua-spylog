-- this is just test how to work with trap
FILTER{ "service-start";
  enabled = false;
  source  = "trap:udp://127.0.0.1";
  exclude = WHITE_IP;
  trap    = "1.3.6.1.4.1.311.1.13.1.23.83.101.114.118.105.99.101.32.67.111.110.116.114.111.108.32.77.97.110.97.103.101.114";
  failregex = {
    --cp1251
    'Служба "([^\"]+)" перешла в состояние';
  }
};
